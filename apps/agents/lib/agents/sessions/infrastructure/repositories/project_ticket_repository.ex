defmodule Agents.Sessions.Infrastructure.Repositories.ProjectTicketRepository do
  @moduledoc """
  Repository for persisted session sidebar project tickets.
  """

  import Ecto.Query, warn: false

  alias Agents.Repo
  alias Agents.Sessions.Infrastructure.Schemas.ProjectTicketSchema

  @default_statuses ["Backlog", "Ready"]

  @spec list_by_statuses([String.t()]) :: [ProjectTicketSchema.t()]
  def list_by_statuses(statuses \\ @default_statuses) do
    ProjectTicketSchema
    |> where([ticket], ticket.status in ^statuses)
    |> order_by([ticket], asc: ticket.number)
    |> Repo.all()
  end

  @spec list_pending_push() :: [ProjectTicketSchema.t()]
  def list_pending_push do
    ProjectTicketSchema
    |> where([ticket], ticket.sync_state == "pending_push")
    |> order_by([ticket], asc: ticket.updated_at)
    |> Repo.all()
  end

  @spec sync_remote_ticket(map(), keyword()) ::
          {:ok, ProjectTicketSchema.t()} | {:error, Ecto.Changeset.t()}
  def sync_remote_ticket(attrs, opts \\ []) do
    now = Keyword.get(opts, :synced_at, DateTime.utc_now() |> DateTime.truncate(:second))

    remote_attrs = normalize_remote_attrs(attrs)
    number = remote_attrs.number
    ticket = Repo.get_by(ProjectTicketSchema, number: number)
    attrs = merge_remote_attrs(ticket, remote_attrs, now)

    ticket = ticket || %ProjectTicketSchema{}

    ticket
    |> ProjectTicketSchema.changeset(attrs)
    |> Repo.insert_or_update()
  end

  @spec update_local_ticket(integer(), map()) ::
          {:ok, ProjectTicketSchema.t()} | {:error, Ecto.Changeset.t()} | {:error, :not_found}
  def update_local_ticket(number, attrs) when is_integer(number) and is_map(attrs) do
    case Repo.get_by(ProjectTicketSchema, number: number) do
      nil ->
        {:error, :not_found}

      ticket ->
        ticket
        |> ProjectTicketSchema.changeset(
          attrs
          |> normalize_local_attrs()
          |> Map.put(:sync_state, "pending_push")
        )
        |> Repo.update()
    end
  end

  @spec mark_sync_success(ProjectTicketSchema.t()) ::
          {:ok, ProjectTicketSchema.t()} | {:error, Ecto.Changeset.t()}
  def mark_sync_success(%ProjectTicketSchema{} = ticket) do
    ticket
    |> ProjectTicketSchema.changeset(%{
      sync_state: "synced",
      last_synced_at: DateTime.utc_now() |> DateTime.truncate(:second),
      last_sync_error: nil
    })
    |> Repo.update()
  end

  @spec mark_sync_error(ProjectTicketSchema.t(), term()) ::
          {:ok, ProjectTicketSchema.t()} | {:error, Ecto.Changeset.t()}
  def mark_sync_error(%ProjectTicketSchema{} = ticket, reason) do
    ticket
    |> ProjectTicketSchema.changeset(%{
      sync_state: "sync_error",
      last_sync_error: inspect(reason)
    })
    |> Repo.update()
  end

  defp normalize_remote_attrs(attrs) do
    %{
      number: attrs[:number] || attrs["number"],
      external_id: attrs[:external_id] || attrs["external_id"],
      title: attrs[:title] || attrs["title"],
      body: attrs[:body] || attrs["body"],
      status: attrs[:status] || attrs["status"],
      priority: attrs[:priority] || attrs["priority"],
      size: attrs[:size] || attrs["size"],
      labels: List.wrap(attrs[:labels] || attrs["labels"]),
      url: attrs[:url] || attrs["url"]
    }
  end

  defp normalize_local_attrs(attrs) do
    attrs
    |> Map.take([:title, :status, :priority, :size, :labels, :url])
    |> Map.update(:labels, [], &List.wrap/1)
  end

  defp merge_remote_attrs(nil, remote_attrs, now) do
    remote_attrs
    |> Map.put(:sync_state, "synced")
    |> Map.put(:last_synced_at, now)
    |> Map.put(:last_sync_error, nil)
  end

  defp merge_remote_attrs(%ProjectTicketSchema{} = ticket, remote_attrs, now) do
    if ticket.sync_state in ["pending_push", "sync_error"] do
      remote_attrs
      |> Map.put(:title, ticket.title)
      |> Map.put(:status, ticket.status)
      |> Map.put(:priority, ticket.priority)
      |> Map.put(:size, ticket.size)
      |> Map.put(:labels, ticket.labels)
      |> Map.put(:url, ticket.url)
      |> Map.put(:sync_state, ticket.sync_state)
      |> Map.put(:last_synced_at, ticket.last_synced_at)
      |> Map.put(:last_sync_error, ticket.last_sync_error)
    else
      remote_attrs
      |> Map.put(:sync_state, "synced")
      |> Map.put(:last_synced_at, now)
      |> Map.put(:last_sync_error, nil)
    end
  end
end
