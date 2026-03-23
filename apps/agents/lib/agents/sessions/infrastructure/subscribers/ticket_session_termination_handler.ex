defmodule Agents.Sessions.Infrastructure.Subscribers.TicketSessionTerminationHandler do
  @moduledoc """
  Terminates ticket-scoped sessions when ticket lifecycle events require cleanup.

  Triggers termination on:
  - `tickets.ticket_closed`
  - `tickets.ticket_stage_changed` when the stage becomes `closed`
  - `pipeline.pull_request_merged` (when linked_ticket is present)
  """

  use Perme8.Events.EventHandler

  alias Agents.Sessions.Application.UseCases.TerminateTicketSession
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository

  @impl Perme8.Events.EventHandler
  def subscriptions, do: ["events:tickets:ticket", "events:pipeline:pull_request"]

  @impl Perme8.Events.EventHandler
  def handle_event(%{event_type: "tickets.ticket_closed", number: ticket_number})
      when is_integer(ticket_number) do
    terminator().(ticket_number, [])
  end

  def handle_event(%{
        event_type: "tickets.ticket_stage_changed",
        ticket_id: ticket_id,
        to_stage: "closed"
      })
      when is_integer(ticket_id) do
    case ticket_repo().get_by_id(ticket_id) do
      {:ok, %{number: ticket_number}} -> terminator().(ticket_number, [])
      _ -> :ok
    end
  end

  def handle_event(%{event_type: "pipeline.pull_request_merged", linked_ticket: ticket_number})
      when is_integer(ticket_number) do
    terminator().(ticket_number, [])
  end

  def handle_event(_event), do: :ok

  defp terminator do
    Application.get_env(:agents, :ticket_session_terminator, &TerminateTicketSession.execute/2)
  end

  defp ticket_repo do
    Application.get_env(:agents, :ticket_session_ticket_repo, ProjectTicketRepository)
  end
end
