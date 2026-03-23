defmodule Agents.Sessions.Infrastructure.Subscribers.TicketSessionTerminationHandler do
  @moduledoc """
  Terminates ticket-scoped sessions when ticket lifecycle events require cleanup.

  Triggers termination on:
  - `tickets.ticket_closed`
  - `tickets.ticket_stage_changed` when the stage becomes `closed`
  - `pipeline.pull_request_merged` (when linked_ticket is present)
  """

  use Perme8.Events.EventHandler

  require Logger

  alias Agents.Sessions.Application.UseCases.TerminateTicketSession
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository

  @impl Perme8.Events.EventHandler
  def subscriptions, do: ["events:tickets:ticket", "events:pipeline:pull_request"]

  @impl Perme8.Events.EventHandler
  def handle_event(%{event_type: "tickets.ticket_closed", number: ticket_number})
      when is_integer(ticket_number) do
    safely_terminate(ticket_number)
  end

  def handle_event(%{
        event_type: "tickets.ticket_stage_changed",
        ticket_id: ticket_id,
        to_stage: "closed"
      })
      when is_integer(ticket_id) do
    safely_terminate_from_ticket_id(ticket_id)
  end

  def handle_event(%{event_type: "pipeline.pull_request_merged", linked_ticket: ticket_number})
      when is_integer(ticket_number) do
    safely_terminate(ticket_number)
  end

  def handle_event(_event), do: :ok

  defp terminator do
    Application.get_env(:agents, :ticket_session_terminator, &TerminateTicketSession.execute/2)
  end

  defp ticket_repo do
    Application.get_env(:agents, :ticket_session_ticket_repo, ProjectTicketRepository)
  end

  defp safely_terminate(ticket_number) do
    terminator().(ticket_number, [])
  rescue
    error ->
      Logger.warning(
        "TicketSessionTerminationHandler failed to terminate ticket session for ##{ticket_number}: #{inspect(error)}"
      )

      :ok
  catch
    :exit, reason ->
      Logger.warning(
        "TicketSessionTerminationHandler termination exited for ##{ticket_number}: #{inspect(reason)}"
      )

      :ok
  end

  defp safely_terminate_from_ticket_id(ticket_id) do
    case ticket_repo().get_by_id(ticket_id) do
      {:ok, %{number: ticket_number}} -> safely_terminate(ticket_number)
      _ -> :ok
    end
  rescue
    error ->
      Logger.warning(
        "TicketSessionTerminationHandler failed to load ticket ##{ticket_id} for termination: #{inspect(error)}"
      )

      :ok
  catch
    :exit, reason ->
      Logger.warning(
        "TicketSessionTerminationHandler ticket lookup exited for ##{ticket_id}: #{inspect(reason)}"
      )

      :ok
  end
end
