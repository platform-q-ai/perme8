defmodule Agents.Tickets.Application.UseCases.CloseTicketTest do
  use Agents.DataCase, async: true

  alias Agents.Repo
  alias Agents.Tickets.Application.UseCases.CloseTicket
  alias Agents.Tickets.Domain.Events.TicketClosed
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema
  alias Perme8.Events.TestEventBus

  @actor_id "user-123"
  @default_opts [actor_id: @actor_id, event_bus: TestEventBus]

  setup do
    TestEventBus.start_global()

    {:ok, ticket} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 300,
        title: "Closable ticket",
        body: "Some body",
        state: "open",
        labels: ["agents"]
      })

    %{ticket: ticket}
  end

  describe "execute/2" do
    test "closes ticket locally with pending_push sync state", %{ticket: _ticket} do
      assert :ok = CloseTicket.execute(300, @default_opts)

      refreshed = Repo.get_by!(ProjectTicketSchema, number: 300)
      assert refreshed.state == "closed"
      assert refreshed.sync_state == "pending_push"
    end

    test "emits TicketClosed event", %{ticket: ticket} do
      assert :ok = CloseTicket.execute(300, @default_opts)

      events = TestEventBus.get_events()
      assert [%TicketClosed{} = event] = events
      assert event.ticket_id == ticket.id
      assert event.number == 300
      assert event.actor_id == @actor_id
    end

    test "returns error for non-existent ticket" do
      assert {:error, :not_found} = CloseTicket.execute(99_999, @default_opts)
      assert TestEventBus.get_events() == []
    end

    test "closing an already-closed ticket succeeds (idempotent)" do
      assert :ok = CloseTicket.execute(300, @default_opts)
      TestEventBus.reset()

      # Second close should also succeed
      assert :ok = CloseTicket.execute(300, @default_opts)

      refreshed = Repo.get_by!(ProjectTicketSchema, number: 300)
      assert refreshed.state == "closed"
      assert refreshed.sync_state == "pending_push"
      # Re-emits the event (handler is idempotent for GitHub close)
      assert [%TicketClosed{}] = TestEventBus.get_events()
    end

    test "requires actor_id" do
      assert_raise KeyError, ~r/key :actor_id not found/, fn ->
        CloseTicket.execute(300, event_bus: TestEventBus)
      end
    end
  end
end
