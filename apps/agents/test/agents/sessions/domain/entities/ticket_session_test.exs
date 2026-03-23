defmodule Agents.Sessions.Domain.Entities.TicketSessionTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Entities.TicketSession

  describe "new/1" do
    test "builds a ticket-scoped session struct" do
      now = DateTime.utc_now()

      session =
        TicketSession.new(%{
          ticket_number: 507,
          session_id: "session-1",
          state: :active,
          container_id: "container-1",
          container_port: 4096,
          last_activity_at: now
        })

      assert session.ticket_number == 507
      assert session.session_id == "session-1"
      assert session.state == :active
      assert session.container_id == "container-1"
      assert session.container_port == 4096
      assert session.last_activity_at == now
    end

    test "defaults state to idle" do
      session = TicketSession.new(%{ticket_number: 507})

      assert session.state == :idle
    end
  end

  describe "state helpers" do
    test "supports the four ticket session lifecycle states" do
      assert TicketSession.valid_states() == [:active, :idle, :suspended, :terminated]
      assert TicketSession.active?(%TicketSession{state: :active})
      assert TicketSession.idle?(%TicketSession{state: :idle})
      assert TicketSession.suspended?(%TicketSession{state: :suspended})
      assert TicketSession.terminated?(%TicketSession{state: :terminated})
    end
  end
end
