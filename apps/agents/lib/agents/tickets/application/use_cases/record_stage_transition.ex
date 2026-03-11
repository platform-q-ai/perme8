defmodule Agents.Tickets.Application.UseCases.RecordStageTransition do
  @moduledoc """
  Records a ticket lifecycle stage transition.

  The lifecycle event insert and ticket stage update are wrapped in a
  database transaction so both succeed or fail atomically.  The domain
  event is emitted **after** the transaction commits.
  """

  alias Agents.Tickets.Domain.Events.TicketStageChanged
  alias Agents.Tickets.Domain.Policies.TicketLifecyclePolicy

  @default_ticket_repo Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  @default_lifecycle_repo Agents.Tickets.Infrastructure.Repositories.TicketLifecycleEventRepository
  @default_event_bus Perme8.Events.EventBus
  @default_repo Agents.Repo

  @spec execute(integer(), String.t(), keyword()) ::
          {:ok, %{ticket: map(), lifecycle_event: map()}} | {:error, term()}
  def execute(ticket_id, to_stage, opts \\ []) do
    ticket_repo = Keyword.get(opts, :ticket_repo, @default_ticket_repo)
    lifecycle_repo = Keyword.get(opts, :lifecycle_repo, @default_lifecycle_repo)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    repo = Keyword.get(opts, :repo, @default_repo)
    trigger = Keyword.get(opts, :trigger, "system")
    now = Keyword.get(opts, :now, DateTime.utc_now() |> DateTime.truncate(:second))

    with {:ok, ticket} <- fetch_ticket(ticket_repo, ticket_id),
         :ok <- TicketLifecyclePolicy.valid_transition?(ticket.lifecycle_stage, to_stage) do
      transaction_result =
        repo.transaction(fn ->
          with {:ok, lifecycle_event} <-
                 lifecycle_repo.create(%{
                   ticket_id: ticket_id,
                   from_stage: ticket.lifecycle_stage,
                   to_stage: to_stage,
                   transitioned_at: now,
                   trigger: trigger
                 }),
               {:ok, updated_ticket} <-
                 ticket_repo.update_lifecycle_stage(ticket_id, to_stage, now) do
            %{ticket: updated_ticket, lifecycle_event: lifecycle_event}
          else
            {:error, reason} -> repo.rollback(reason)
          end
        end)

      case transaction_result do
        {:ok, result} ->
          event_bus.emit(
            TicketStageChanged.new(%{
              aggregate_id: to_string(ticket_id),
              actor_id: trigger,
              ticket_id: ticket_id,
              from_stage: ticket.lifecycle_stage,
              to_stage: to_stage,
              trigger: trigger
            })
          )

          {:ok, result}

        {:error, _reason} = error ->
          error
      end
    end
  end

  defp fetch_ticket(ticket_repo, ticket_id) do
    case ticket_repo.get_by_id(ticket_id) do
      {:ok, ticket} -> {:ok, ticket}
      nil -> {:error, :ticket_not_found}
      {:error, _} = error -> error
    end
  end
end
