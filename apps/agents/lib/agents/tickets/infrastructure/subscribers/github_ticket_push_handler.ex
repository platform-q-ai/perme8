defmodule Agents.Tickets.Infrastructure.Subscribers.GithubTicketPushHandler do
  @moduledoc """
  Event handler that pushes locally-created tickets to GitHub.

  Listens for `tickets.ticket_created` domain events and creates the
  corresponding GitHub issue via the REST API. On success, updates the
  local ticket record with the real GitHub issue number and URL, and
  triggers a UI refresh.
  """

  use Perme8.Events.EventHandler

  require Logger

  alias Agents.Tickets.Application.TicketsConfig
  alias Agents.Tickets.Infrastructure.Clients.GithubProjectClient
  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema

  @pubsub Perme8.Events.PubSub
  @tickets_topic "sessions:tickets"

  @impl Perme8.Events.EventHandler
  def subscriptions, do: ["events:tickets:ticket"]

  @impl Perme8.Events.EventHandler
  def handle_event(%{event_type: "tickets.ticket_created"} = event) do
    push_to_github(event.ticket_id, event.title, event.body)
  end

  def handle_event(_event), do: :ok

  defp push_to_github(ticket_id, title, body) do
    opts = [
      token: TicketsConfig.github_token(),
      org: TicketsConfig.github_org(),
      repo: TicketsConfig.github_repo(),
      api_base: TicketsConfig.github_api_base()
    ]

    issue_body = if body in [nil, ""], do: "", else: body

    attrs = %{"title" => title, "body" => issue_body}

    case GithubProjectClient.create_issue(attrs, opts) do
      {:ok, issue} ->
        update_local_ticket(ticket_id, issue)
        broadcast_tickets_refresh()
        :ok

      {:error, reason} ->
        Logger.error("Failed to push ticket #{ticket_id} to GitHub: #{inspect(reason)}")
        mark_sync_error(ticket_id, reason)
        {:error, reason}
    end
  end

  defp update_local_ticket(ticket_id, issue) do
    import Ecto.Query, warn: false

    changeset =
      ProjectTicketSchema
      |> Agents.Repo.get!(ticket_id)
      |> ProjectTicketSchema.changeset(%{
        number: issue.number,
        url: issue.url,
        sync_state: "synced",
        last_synced_at: DateTime.utc_now() |> DateTime.truncate(:second)
      })

    case Agents.Repo.update(changeset) do
      {:ok, _} -> :ok
      {:error, reason} -> Logger.error("Failed to update ticket #{ticket_id}: #{inspect(reason)}")
    end
  rescue
    e ->
      Logger.error("Failed to update ticket #{ticket_id}: #{Exception.message(e)}")
      :ok
  end

  defp mark_sync_error(ticket_id, reason) do
    import Ecto.Query, warn: false

    case Agents.Repo.get(ProjectTicketSchema, ticket_id) do
      nil ->
        :ok

      ticket ->
        ticket
        |> ProjectTicketSchema.changeset(%{
          sync_state: "sync_error",
          last_sync_error: inspect(reason)
        })
        |> Agents.Repo.update()
    end
  rescue
    e ->
      Logger.error("Failed to mark ticket #{ticket_id} as sync_error: #{Exception.message(e)}")

      :ok
  end

  defp broadcast_tickets_refresh do
    Phoenix.PubSub.broadcast(@pubsub, @tickets_topic, {:tickets_synced, []})
  end
end
