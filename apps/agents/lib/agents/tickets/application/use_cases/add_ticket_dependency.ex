defmodule Agents.Tickets.Application.UseCases.AddTicketDependency do
  @moduledoc """
  Use case for adding a dependency between two tickets.

  Validates that both tickets exist, the dependency is not a self-reference,
  duplicate, or circular, then inserts the relationship and emits a domain event.
  """

  alias Agents.Tickets.Domain.Events.TicketDependencyChanged
  alias Agents.Tickets.Domain.Policies.TicketDependencyPolicy
  alias Agents.Tickets.Infrastructure.Repositories.TicketDependencyRepository

  @default_event_bus Perme8.Events.EventBus
  @default_dependency_repo TicketDependencyRepository
  @default_pubsub Perme8.Events.PubSub
  @tickets_topic "sessions:tickets"

  @doc """
  Adds a dependency: blocker_ticket_id blocks blocked_ticket_id.

  ## Options
  - `:actor_id` - (required) The user performing the action
  - `:event_bus` - Event bus module (default: EventBus)
  - `:dependency_repo` - Repository module (default: TicketDependencyRepository)
  """
  @spec execute(integer(), integer(), keyword()) :: {:ok, struct()} | {:error, term()}
  def execute(blocker_ticket_id, blocked_ticket_id, opts \\ []) do
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    dep_repo = Keyword.get(opts, :dependency_repo, @default_dependency_repo)
    actor_id = Keyword.fetch!(opts, :actor_id)

    with :ok <- validate_not_self(blocker_ticket_id, blocked_ticket_id),
         :ok <- validate_tickets_exist(blocker_ticket_id, blocked_ticket_id, dep_repo),
         :ok <- validate_not_duplicate(blocker_ticket_id, blocked_ticket_id, dep_repo),
         :ok <- validate_not_circular(blocker_ticket_id, blocked_ticket_id, dep_repo) do
      case dep_repo.add_dependency(blocker_ticket_id, blocked_ticket_id) do
        {:ok, dependency} ->
          emit_event(blocker_ticket_id, blocked_ticket_id, :added, actor_id, event_bus)
          broadcast_tickets_refresh()
          {:ok, dependency}

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  defp validate_not_self(id, id), do: {:error, :self_dependency}
  defp validate_not_self(_, _), do: :ok

  defp validate_tickets_exist(blocker_id, blocked_id, dep_repo) do
    cond do
      not dep_repo.ticket_exists?(blocker_id) -> {:error, :blocker_not_found}
      not dep_repo.ticket_exists?(blocked_id) -> {:error, :blocked_not_found}
      true -> :ok
    end
  end

  defp validate_not_duplicate(blocker_id, blocked_id, dep_repo) do
    edges = dep_repo.list_edges()

    if TicketDependencyPolicy.duplicate_dependency?(edges, {blocker_id, blocked_id}) do
      {:error, :duplicate_dependency}
    else
      :ok
    end
  end

  defp validate_not_circular(blocker_id, blocked_id, dep_repo) do
    edges = dep_repo.list_edges()

    if TicketDependencyPolicy.circular_dependency?(edges, blocker_id, blocked_id) do
      {:error, :circular_dependency}
    else
      :ok
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
