defmodule Agents.Tickets.Infrastructure.Subscribers.GithubTicketPushHandler do
  @moduledoc """
  Event handler that synchronises local ticket changes to GitHub.

  Listens for ticket domain events on the `events:tickets:ticket` topic
  and pushes changes to GitHub via the REST API:

  - `tickets.ticket_created` -- creates a new GitHub issue and updates
    the local record with the real issue number and URL.
  - `tickets.ticket_updated` -- pushes field changes (title, body, labels,
    state, etc.) to the corresponding GitHub issue via PATCH. Skips tickets
    with temporary (negative) numbers that haven't been created on GitHub yet.
  - `tickets.ticket_closed` -- closes the corresponding GitHub issue
    and marks the local record as synced.

  On success, marks the ticket as `sync_state: "synced"`. On failure,
  marks it as `sync_state: "sync_error"` and logs the error.
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

  def handle_event(%{event_type: "tickets.ticket_updated"} = event) do
    push_update_to_github(event.ticket_id, event.number, event.changes)
  end

  def handle_event(%{event_type: "tickets.ticket_closed"} = event) do
    close_on_github(event.ticket_id, event.number)
  end

  def handle_event(_event), do: :ok

  defp push_update_to_github(_ticket_id, number, _changes) when number < 0 do
    # Ticket hasn't been pushed to GitHub yet (temporary number).
    # The pending changes will be included when the ticket is eventually
    # created on GitHub via the ticket_created handler.
    :ok
  end

  defp push_update_to_github(ticket_id, number, changes) do
    opts = [
      token: TicketsConfig.github_token(),
      org: TicketsConfig.github_org(),
      repo: TicketsConfig.github_repo(),
      api_base: TicketsConfig.github_api_base()
    ]

    case GithubProjectClient.update_issue(number, changes, opts) do
      {:ok, _issue} ->
        mark_synced(ticket_id)
        broadcast_tickets_refresh()
        :ok

      {:error, reason} ->
        Logger.error(
          "Failed to push ticket update #{ticket_id} (issue ##{number}) to GitHub: #{inspect(reason)}"
        )

        mark_sync_error(ticket_id, reason)
        {:error, reason}
    end
  end

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

  defp close_on_github(ticket_id, number) do
    opts = [
      token: TicketsConfig.github_token(),
      org: TicketsConfig.github_org(),
      repo: TicketsConfig.github_repo(),
      api_base: TicketsConfig.github_api_base()
    ]

    case GithubProjectClient.update_issue(number, %{state: "closed"}, opts) do
      {:error, reason} when reason != :not_found ->
        Logger.error("Failed to close ticket ##{number} on GitHub: #{inspect(reason)}")
        mark_sync_error(ticket_id, reason)
        {:error, reason}

      _ok_or_not_found ->
        mark_synced(ticket_id)
        broadcast_tickets_refresh()
        :ok
    end
  rescue
    e ->
      Logger.error("Failed to close ticket ##{number} on GitHub: #{Exception.message(e)}")
      mark_sync_error(ticket_id, Exception.message(e))
      :ok
  end

  defp mark_synced(ticket_id) do
    try do
      case Agents.Repo.get(ProjectTicketSchema, ticket_id) do
        nil ->
          :ok

        ticket ->
          changeset =
            ProjectTicketSchema.changeset(ticket, %{
              sync_state: "synced",
              last_synced_at: DateTime.utc_now() |> DateTime.truncate(:second)
            })

          case Agents.Repo.update(changeset) do
            {:ok, _} ->
              :ok

            {:error, reason} ->
              Logger.error("Failed to mark ticket #{ticket_id} as synced: #{inspect(reason)}")
          end
      end
    catch
      :exit, reason ->
        Logger.error("Failed to mark ticket #{ticket_id} as synced: #{inspect(reason)}")
        :ok
    end
  rescue
    e ->
      Logger.error("Failed to mark ticket #{ticket_id} as synced: #{Exception.message(e)}")
      :ok
  end

  defp update_local_ticket(ticket_id, issue) do
    import Ecto.Query, warn: false

    try do
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
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.error("Failed to update ticket #{ticket_id}: #{inspect(reason)}")
      end
    catch
      :exit, reason ->
        Logger.error("Failed to update ticket #{ticket_id}: #{inspect(reason)}")
        :ok
    end
  rescue
    e ->
      Logger.error("Failed to update ticket #{ticket_id}: #{Exception.message(e)}")
      :ok
  end

  defp mark_sync_error(ticket_id, reason) do
    import Ecto.Query, warn: false

    try do
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
    catch
      :exit, exit_reason ->
        Logger.error("Failed to mark ticket #{ticket_id} as sync_error: #{inspect(exit_reason)}")
        :ok
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
