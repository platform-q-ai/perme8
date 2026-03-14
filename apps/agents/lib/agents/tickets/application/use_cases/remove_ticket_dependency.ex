defmodule Agents.Tickets.Application.UseCases.RemoveTicketDependency do
  @moduledoc """
  Use case for removing a dependency between two tickets.
  """

  alias Agents.Tickets.Domain.Events.TicketDependencyChanged
  alias Agents.Tickets.Infrastructure.Repositories.TicketDependencyRepository

  @default_event_bus Perme8.Events.EventBus
  @default_dependency_repo TicketDependencyRepository
  @default_pubsub Perme8.Events.PubSub
  @tickets_topic "sessions:tickets"

  @doc """
  Removes a dependency: blocker_ticket_id no longer blocks blocked_ticket_id.

  ## Options
  - `:actor_id` - (required) The user performing the action
  - `:event_bus` - Event bus module (default: EventBus)
  - `:dependency_repo` - Repository module (default: TicketDependencyRepository)
  """
  @spec execute(integer(), integer(), keyword()) :: :ok | {:error, :dependency_not_found}
  def execute(blocker_ticket_id, blocked_ticket_id, opts \\ []) do
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    dep_repo = Keyword.get(opts, :dependency_repo, @default_dependency_repo)
    actor_id = Keyword.fetch!(opts, :actor_id)

    case dep_repo.remove_dependency(blocker_ticket_id, blocked_ticket_id) do
      :ok ->
        emit_event(blocker_ticket_id, blocked_ticket_id, :removed, actor_id, event_bus)
        broadcast_tickets_refresh()
        :ok

      {:error, :not_found} ->
        {:error, :dependency_not_found}
    end
  end

  defp emit_event(blocker_id, blocked_id, action, actor_id, event_bus) do
    event_bus.emit(
      TicketDependencyChanged.new(%{
        aggregate_id: to_string(blocker_id),
        actor_id: actor_id,
        blocker_ticket_id: blocker_id,
        blocked_ticket_id: blocked_id,
        action: action
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
