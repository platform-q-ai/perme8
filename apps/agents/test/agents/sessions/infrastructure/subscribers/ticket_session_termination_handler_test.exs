defmodule Agents.Sessions.Infrastructure.Subscribers.TicketSessionTerminationHandlerTest do
  use ExUnit.Case, async: false

  alias Agents.Sessions.Infrastructure.Subscribers.TicketSessionTerminationHandler

  setup do
    original = Application.get_env(:agents, :ticket_session_terminator)
    original_ticket_repo = Application.get_env(:agents, :ticket_session_ticket_repo)

    on_exit(fn ->
      if original == nil do
        Application.delete_env(:agents, :ticket_session_terminator)
      else
        Application.put_env(:agents, :ticket_session_terminator, original)
      end

      if original_ticket_repo == nil do
        Application.delete_env(:agents, :ticket_session_ticket_repo)
      else
        Application.put_env(:agents, :ticket_session_ticket_repo, original_ticket_repo)
      end
    end)

    :ok
  end

  test "subscribes to ticket and pull request event topics" do
    assert "events:tickets:ticket" in TicketSessionTerminationHandler.subscriptions()
    assert "events:pipeline:pull_request" in TicketSessionTerminationHandler.subscriptions()
  end

  test "terminates ticket session on ticket_closed event" do
    parent = self()

    Application.put_env(:agents, :ticket_session_terminator, fn ticket_number, _opts ->
      send(parent, {:terminated, ticket_number})
      :ok
    end)

    :ok =
      TicketSessionTerminationHandler.handle_event(%{
        event_type: "tickets.ticket_closed",
        number: 507
      })

    assert_receive {:terminated, 507}
  end

  test "terminates ticket session on ticket_stage_changed to closed" do
    parent = self()

    Application.put_env(:agents, :ticket_session_terminator, fn ticket_number, _opts ->
      send(parent, {:terminated, ticket_number})
      :ok
    end)

    defmodule TicketRepoStub do
      def get_by_id(507), do: {:ok, %{number: 999}}
      def get_by_id(_), do: nil
    end

    Application.put_env(:agents, :ticket_session_ticket_repo, TicketRepoStub)

    :ok =
      TicketSessionTerminationHandler.handle_event(%{
        event_type: "tickets.ticket_stage_changed",
        ticket_id: 507,
        to_stage: "closed"
      })

    assert_receive {:terminated, 999}
  end

  test "ignores ticket_stage_changed events that do not close the ticket" do
    Application.put_env(:agents, :ticket_session_terminator, fn _ticket_number, _opts ->
      flunk("terminator should not be called for non-closed stages")
    end)

    assert :ok =
             TicketSessionTerminationHandler.handle_event(%{
               event_type: "tickets.ticket_stage_changed",
               ticket_id: 507,
               to_stage: "in_review"
             })
  end

  test "terminates ticket session on pull_request_merged event with linked ticket" do
    parent = self()

    Application.put_env(:agents, :ticket_session_terminator, fn ticket_number, _opts ->
      send(parent, {:terminated, ticket_number})
      :ok
    end)

    :ok =
      TicketSessionTerminationHandler.handle_event(%{
        event_type: "pipeline.pull_request_merged",
        linked_ticket: 507
      })

    assert_receive {:terminated, 507}
  end

  test "ignores pull_request_merged events without linked_ticket" do
    Application.put_env(:agents, :ticket_session_terminator, fn _ticket_number, _opts ->
      flunk("terminator should not be called without linked ticket")
    end)

    assert :ok =
             TicketSessionTerminationHandler.handle_event(%{
               event_type: "pipeline.pull_request_merged",
               linked_ticket: nil
             })
  end

  test "rescues ticket lookup failures for ticket_stage_changed events" do
    Application.put_env(:agents, :ticket_session_terminator, fn _ticket_number, _opts ->
      flunk("terminator should not be called when ticket lookup fails")
    end)

    defmodule FailingTicketRepoStub do
      def get_by_id(_ticket_id), do: raise(DBConnection.ConnectionError, message: "owner exited")
    end

    Application.put_env(:agents, :ticket_session_ticket_repo, FailingTicketRepoStub)

    assert :ok =
             TicketSessionTerminationHandler.handle_event(%{
               event_type: "tickets.ticket_stage_changed",
               ticket_id: 507,
               to_stage: "closed"
             })
  end

  test "rescues termination failures for merged pull request events" do
    Application.put_env(:agents, :ticket_session_terminator, fn _ticket_number, _opts ->
      raise(DBConnection.ConnectionError, message: "owner exited")
    end)

    assert :ok =
             TicketSessionTerminationHandler.handle_event(%{
               event_type: "pipeline.pull_request_merged",
               linked_ticket: 507
             })
  end
end
