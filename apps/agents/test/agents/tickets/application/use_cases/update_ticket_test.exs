defmodule Agents.Tickets.Application.UseCases.UpdateTicketTest do
  use Agents.DataCase, async: true

  alias Agents.Tickets.Application.UseCases.UpdateTicket
  alias Agents.Tickets.Domain.Events.TicketUpdated
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Perme8.Events.TestEventBus

  @actor_id "user-123"
  @default_opts [actor_id: @actor_id, event_bus: TestEventBus]

  setup do
    TestEventBus.start_global()

    {:ok, ticket} =
      ProjectTicketRepository.sync_remote_ticket(%{
        number: 200,
        title: "Original title",
        body: "Original body",
        state: "open",
        labels: ["agents"]
      })

    %{ticket: ticket}
  end

  describe "execute/3" do
    test "updates ticket title", %{ticket: _ticket} do
      assert {:ok, schema} = UpdateTicket.execute(200, %{title: "Updated title"}, @default_opts)
      assert schema.title == "Updated title"
    end

    test "updates ticket body", %{ticket: _ticket} do
      assert {:ok, schema} = UpdateTicket.execute(200, %{body: "Updated body"}, @default_opts)
      assert schema.body == "Updated body"
    end

    test "updates ticket labels", %{ticket: _ticket} do
      assert {:ok, schema} =
               UpdateTicket.execute(200, %{labels: ["agents", "bug"]}, @default_opts)

      assert schema.labels == ["agents", "bug"]
    end

    test "sets sync_state to pending_push", %{ticket: _ticket} do
      assert {:ok, schema} = UpdateTicket.execute(200, %{title: "Changed"}, @default_opts)
      assert schema.sync_state == "pending_push"
    end

    test "emits TicketUpdated event", %{ticket: ticket} do
      assert {:ok, _schema} = UpdateTicket.execute(200, %{title: "Changed"}, @default_opts)

      events = TestEventBus.get_events()
      assert [%TicketUpdated{} = event] = events
      assert event.ticket_id == ticket.id
      assert event.number == 200
      assert event.changes == %{title: "Changed"}
      assert event.actor_id == @actor_id
    end

    test "returns error for non-existent ticket" do
      assert {:error, :not_found} = UpdateTicket.execute(999, %{title: "Nope"}, @default_opts)
      assert TestEventBus.get_events() == []
    end

    test "returns error when no updatable fields provided" do
      assert {:error, :no_changes} = UpdateTicket.execute(200, %{}, @default_opts)
      assert TestEventBus.get_events() == []
    end

    test "filters out non-updatable fields" do
      assert {:error, :no_changes} =
               UpdateTicket.execute(200, %{number: 999, sync_state: "synced"}, @default_opts)
    end
  end
end
