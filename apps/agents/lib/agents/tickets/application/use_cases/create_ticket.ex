defmodule Agents.Tickets.Application.UseCases.CreateTicket do
  @moduledoc """
  Use case for creating a new ticket locally.

  Parses the user input (first line = title, rest = body), inserts a
  local ticket record with `sync_state: "pending_push"`, emits a
  `TicketCreated` domain event, and broadcasts a ticket refresh so the
  UI updates immediately.

  The actual push to GitHub happens asynchronously via an event handler
  listening for the `TicketCreated` event.
  """

  alias Agents.Tickets.Domain.Events.TicketCreated

  @default_event_bus Perme8.Events.EventBus
  @default_ticket_repo Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  @default_pubsub Perme8.Events.PubSub
  @tickets_topic "sessions:tickets"

  @doc """
  Creates a new ticket from raw user input.

  ## Parameters
  - `body` - The raw text. First line becomes the title; remaining lines
    become the body.
  - `opts` - Keyword list with:
    - `:actor_id` - (required) The user creating the ticket
    - `:event_bus` - Event bus module (default: EventBus)
    - `:ticket_repo` - Repository module (default: ProjectTicketRepository)

  ## Returns
  - `{:ok, schema}` on success
  - `{:error, :body_required}` when input is blank
  - `{:error, changeset}` on validation failure
  """
  @spec execute(String.t(), keyword()) :: {:ok, struct()} | {:error, term()}
  def execute(body, opts \\ []) do
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    ticket_repo = Keyword.get(opts, :ticket_repo, @default_ticket_repo)
    actor_id = Keyword.fetch!(opts, :actor_id)

    with :ok <- validate_body(body) do
      {title, ticket_body} = split_title_body(body)

      insert_and_emit(title, ticket_body, actor_id, ticket_repo, event_bus)
    end
  end

  defp validate_body(body) when is_binary(body) do
    if String.trim(body) == "", do: {:error, :body_required}, else: :ok
  end

  defp validate_body(_), do: {:error, :body_required}

  defp split_title_body(text) do
    case String.split(text, "\n", parts: 2) do
      [title] -> {String.trim(title), ""}
      [title, rest] -> {String.trim(title), String.trim(rest)}
    end
  end

  defp insert_and_emit(title, body, actor_id, ticket_repo, event_bus) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    temp_number = generate_temp_number()

    attrs = %{
      number: temp_number,
      title: title,
      body: body,
      state: "open",
      sync_state: "pending_push",
      position: ticket_repo.next_position(),
      created_at: now
    }

    case ticket_repo.insert_local(attrs) do
      {:ok, schema} ->
        emit_ticket_created(schema, actor_id, event_bus)
        broadcast_tickets_refresh()
        {:ok, schema}

      error ->
        error
    end
  end

  defp generate_temp_number do
    # Use a negative number to avoid collision with GitHub issue numbers
    # (always positive). The GitHub push handler will update this to the
    # real issue number after creation.
    # Use rem to stay within 32-bit signed integer range for the DB column.
    -rem(System.os_time(:microsecond), 2_000_000_000)
  end

  defp emit_ticket_created(schema, actor_id, event_bus) do
    event_bus.emit(
      TicketCreated.new(%{
        aggregate_id: to_string(schema.id),
        actor_id: actor_id,
        ticket_id: schema.id,
        title: schema.title,
        body: schema.body
      })
    )
  end

  defp broadcast_tickets_refresh do
    Phoenix.PubSub.broadcast(
      @default_pubsub,
      @tickets_topic,
      {:tickets_synced, []}
    )
  end
end
