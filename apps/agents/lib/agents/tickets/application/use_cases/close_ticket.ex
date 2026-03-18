defmodule Agents.Tickets.Application.UseCases.CloseTicket do
  @moduledoc """
  Use case for closing a ticket locally.

  Sets `state` to `"closed"` and `sync_state` to `"pending_push"`,
  emits a `TicketClosed` domain event, and broadcasts a ticket refresh
  so the UI updates immediately.

  The actual close on GitHub happens asynchronously via the
  `GithubTicketPushHandler` event subscriber.
  """

  require Logger

  alias Agents.Tickets.Domain.Events.TicketClosed

  @default_event_bus Perme8.Events.EventBus
  @default_ticket_repo Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  @default_pubsub Perme8.Events.PubSub
  @tickets_topic "sessions:tickets"

  @doc """
  Closes a ticket identified by number.

  ## Parameters
  - `number` - The ticket number
  - `opts` - Keyword list with:
    - `:actor_id` - (required) The user closing the ticket
    - `:event_bus` - Event bus module (default: EventBus)
    - `:ticket_repo` - Repository module (default: ProjectTicketRepository)

  ## Returns
  - `:ok` on success
  - `{:error, :not_found}` when ticket doesn't exist
  - `{:error, changeset}` on validation failure
  """
  @spec execute(integer(), keyword()) :: :ok | {:error, term()}
  def execute(number, opts \\ []) do
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    ticket_repo = Keyword.get(opts, :ticket_repo, @default_ticket_repo)
    actor_id = Keyword.fetch!(opts, :actor_id)

    close_attrs = %{state: "closed", sync_state: "pending_push"}

    case ticket_repo.update_fields(number, close_attrs) do
      {:ok, schema} ->
        safely_emit_and_broadcast(schema, actor_id, event_bus)
        :ok

      {:error, :not_found} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp safely_emit_and_broadcast(schema, actor_id, event_bus) do
    emit_event(schema, actor_id, event_bus)
    broadcast_tickets_refresh()
  rescue
    e ->
      Logger.error(
        "Failed to emit TicketClosed event for ticket ##{schema.number}: #{Exception.message(e)}"
      )
  end

  defp emit_event(schema, actor_id, event_bus) do
    event_bus.emit(
      TicketClosed.new(%{
        aggregate_id: to_string(schema.id),
        actor_id: actor_id,
        ticket_id: schema.id,
        number: schema.number
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
