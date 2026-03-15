defmodule Agents.Tickets.Application.UseCases.RemoveSubIssue do
  @moduledoc """
  Use case for unlinking a child ticket from its parent ticket.

  Clears `parent_ticket_id` on the child ticket, emits a
  `TicketSubIssueChanged` domain event, and broadcasts a ticket refresh.

  The actual push to GitHub happens asynchronously via an event handler.
  """

  alias Agents.Tickets.Domain.Events.TicketSubIssueChanged

  @default_event_bus Perme8.Events.EventBus
  @default_ticket_repo Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  @default_pubsub Perme8.Events.PubSub
  @tickets_topic "sessions:tickets"

  @doc """
  Unlinks a child ticket from its parent.

  ## Parameters
  - `parent_number` - The parent ticket number (used for event context)
  - `child_number` - The child ticket number to unlink
  - `opts` - Keyword list with:
    - `:actor_id` - (required) The user making the change
    - `:event_bus` - Event bus module (default: EventBus)
    - `:ticket_repo` - Repository module (default: ProjectTicketRepository)

  ## Returns
  - `{:ok, schema}` on success (the updated child ticket with nil parent)
  - `{:error, :not_found}` when child doesn't exist
  """
  @spec execute(integer(), integer(), keyword()) :: {:ok, struct()} | {:error, term()}
  def execute(parent_number, child_number, opts \\ []) do
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    ticket_repo = Keyword.get(opts, :ticket_repo, @default_ticket_repo)
    actor_id = Keyword.fetch!(opts, :actor_id)

    case ticket_repo.clear_parent_ticket(child_number) do
      {:ok, schema} ->
        emit_event(parent_number, child_number, :removed, actor_id, event_bus)
        broadcast_tickets_refresh()
        {:ok, schema}

      error ->
        error
    end
  end

  defp emit_event(parent_number, child_number, action, actor_id, event_bus) do
    event_bus.emit(
      TicketSubIssueChanged.new(%{
        aggregate_id: to_string(parent_number),
        actor_id: actor_id,
        parent_number: parent_number,
        child_number: child_number,
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
