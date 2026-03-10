defmodule Agents.Tickets.Domain.Entities.Ticket do
  @moduledoc """
  Pure domain entity for project tickets.

  This is a value object representing ticket state in the business domain.
  It contains no persistence or query concerns.
  """

  @type t :: %__MODULE__{
          id: integer() | nil,
          number: integer() | nil,
          external_id: String.t() | nil,
          title: String.t() | nil,
          body: String.t() | nil,
          status: String.t() | nil,
          state: String.t(),
          priority: String.t() | nil,
          size: String.t() | nil,
          labels: [String.t()],
          url: String.t() | nil,
          position: integer(),
          sync_state: String.t(),
          last_synced_at: DateTime.t() | nil,
          last_sync_error: String.t() | nil,
          remote_updated_at: DateTime.t() | nil,
          parent_ticket_id: integer() | nil,
          sub_tickets: [t()],
          created_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil,
          associated_task_id: String.t() | nil,
          associated_container_id: String.t() | nil,
          session_state: String.t(),
          task_status: String.t() | nil,
          task_error: String.t() | nil
        }

  # Maximum body size forwarded to agents. GitHub issue bodies can be up to 65K
  # characters; truncating avoids bloating context windows with oversized content.
  @max_body_chars 8_000

  defstruct [
    :id,
    :number,
    :external_id,
    :title,
    :body,
    :status,
    :priority,
    :size,
    :url,
    :last_synced_at,
    :last_sync_error,
    :remote_updated_at,
    :parent_ticket_id,
    :created_at,
    :inserted_at,
    :updated_at,
    :associated_task_id,
    :associated_container_id,
    :task_status,
    :task_error,
    state: "open",
    labels: [],
    position: 0,
    sync_state: "synced",
    sub_tickets: [],
    session_state: "idle"
  ]

  @doc "Creates a new Ticket entity from attributes."
  @spec new(map()) :: t()
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc "Converts a schema-like struct to a Ticket entity."
  @spec from_schema(struct()) :: t()
  def from_schema(%{__struct__: _} = schema) do
    %__MODULE__{
      id: schema.id,
      number: schema.number,
      external_id: schema.external_id,
      title: schema.title,
      body: schema.body,
      status: schema.status,
      state: schema.state,
      priority: schema.priority,
      size: schema.size,
      labels: schema.labels || [],
      url: schema.url,
      position: schema.position || 0,
      sync_state: schema.sync_state || "synced",
      last_synced_at: schema.last_synced_at,
      last_sync_error: schema.last_sync_error,
      remote_updated_at: schema.remote_updated_at,
      parent_ticket_id: schema.parent_ticket_id,
      sub_tickets: convert_sub_tickets(schema.sub_tickets),
      created_at: schema.created_at,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at,
      associated_task_id: Map.get(schema, :task_id),
      associated_container_id: nil,
      session_state: "idle",
      task_status: nil,
      task_error: nil
    }
  end

  @doc "Returns true if the ticket's state is open."
  @spec open?(t()) :: boolean()
  def open?(ticket), do: ticket.state == "open"

  @doc "Returns true if the ticket's state is closed."
  @spec closed?(t()) :: boolean()
  def closed?(ticket), do: ticket.state == "closed"

  @doc "Returns true if the ticket has any sub-tickets."
  @spec has_sub_tickets?(t()) :: boolean()
  def has_sub_tickets?(ticket), do: ticket.sub_tickets != [] and ticket.sub_tickets != nil

  @doc "Returns true if this is a root-level ticket (no parent)."
  @spec root_ticket?(t()) :: boolean()
  def root_ticket?(ticket), do: is_nil(ticket.parent_ticket_id)

  @doc "Returns true if this ticket is a sub-ticket of another."
  @spec sub_ticket?(t()) :: boolean()
  def sub_ticket?(ticket), do: not is_nil(ticket.parent_ticket_id)

  @doc "Returns the list of valid ticket states."
  @spec valid_states() :: [String.t()]
  def valid_states, do: ["open", "closed"]

  @doc "Formats a ticket as a structured context block for agent instructions.

  The output is wrapped in `<ticket-context>` delimiters to clearly delineate
  user-controlled content (GitHub issue bodies) from system instructions.
  Ticket bodies exceeding #{@max_body_chars} characters are truncated."
  @spec build_context_block(t()) :: String.t()
  def build_context_block(%__MODULE__{} = ticket) do
    inner =
      [
        "## Ticket ##{ticket.number}: #{ticket.title}",
        format_labels(ticket.labels),
        format_parent(ticket),
        format_body(ticket.body),
        format_sub_tickets(ticket.sub_tickets)
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n\n")

    "<ticket-context>\n#{inner}\n</ticket-context>"
  end

  defp convert_sub_tickets(sub_tickets) when is_list(sub_tickets),
    do: Enum.map(sub_tickets, &from_schema/1)

  defp convert_sub_tickets(_), do: []

  defp format_labels(labels) when is_list(labels) do
    formatted =
      labels
      |> Enum.map(&to_string/1)
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&"##{&1}")

    if formatted == [], do: nil, else: "Labels: #{Enum.join(formatted, " ")}"
  end

  defp format_labels(_), do: nil

  defp format_parent(%__MODULE__{parent_ticket_id: nil}), do: nil

  # parent_ticket_id is the internal DB row id, not the GitHub issue number.
  # The parent's number is not available on the struct, so we label it clearly.
  defp format_parent(%__MODULE__{parent_ticket_id: parent_ticket_id}),
    do: "Parent ticket (internal id: #{parent_ticket_id})"

  defp format_body(body) when is_binary(body) do
    trimmed = String.trim(body)

    cond do
      trimmed == "" ->
        nil

      String.length(trimmed) > @max_body_chars ->
        "Body:\n#{String.slice(trimmed, 0, @max_body_chars)}\n\n[truncated — body exceeded #{@max_body_chars} characters]"

      true ->
        "Body:\n#{trimmed}"
    end
  end

  defp format_body(_), do: nil

  defp format_sub_tickets(sub_tickets) when is_list(sub_tickets) do
    entries =
      sub_tickets
      |> Enum.map(&format_sub_ticket_entry/1)
      |> Enum.reject(&is_nil/1)

    if entries == [], do: nil, else: "Sub-tickets:\n#{Enum.join(entries, "\n")}"
  end

  defp format_sub_tickets(_), do: nil

  defp format_sub_ticket_entry(%__MODULE__{} = ticket),
    do: format_sub_ticket_entry(%{number: ticket.number, title: ticket.title})

  defp format_sub_ticket_entry(%{number: number, title: title}) when is_integer(number) do
    suffix =
      if is_binary(title) and String.trim(title) != "", do: ": #{String.trim(title)}", else: ""

    "- ##{number}#{suffix}"
  end

  defp format_sub_ticket_entry(_), do: nil
end
