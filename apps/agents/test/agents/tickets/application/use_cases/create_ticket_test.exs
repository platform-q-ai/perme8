defmodule Agents.Tickets.Application.UseCases.CreateTicketTest do
  use Agents.DataCase, async: true

  alias Agents.Repo
  alias Agents.Tickets.Application.UseCases.CreateTicket
  alias Agents.Tickets.Domain.Events.TicketCreated
  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema
  alias Perme8.Events.TestEventBus

  @actor_id "user-123"

  # Use TestEventBus for all tests to prevent real PubSub events from reaching
  # the live GithubTicketPushHandler GenServer in the supervision tree, which
  # would crash without sandbox access and potentially take down the supervisor.
  @default_opts [actor_id: @actor_id, event_bus: TestEventBus]

  setup do
    TestEventBus.start_global()
    :ok
  end

  describe "execute/2" do
    test "inserts a local ticket with pending_push sync state" do
      assert {:ok, ticket} = CreateTicket.execute("Fix the login bug", @default_opts)

      assert ticket.title == "Fix the login bug"
      assert ticket.body in ["", nil]
      assert ticket.state == "open"
      assert ticket.sync_state == "pending_push"
      assert ticket.number < 0
      assert ticket.created_at != nil

      # Verify it's persisted
      persisted = Repo.get!(ProjectTicketSchema, ticket.id)
      assert persisted.title == "Fix the login bug"
      assert persisted.sync_state == "pending_push"
    end

    test "splits first line as title and rest as body" do
      input = "Fix the login bug\n\nThe login form crashes when email contains a plus sign."

      assert {:ok, ticket} = CreateTicket.execute(input, @default_opts)

      assert ticket.title == "Fix the login bug"
      assert ticket.body == "The login form crashes when email contains a plus sign."
    end

    test "single line input sets title and empty body" do
      assert {:ok, ticket} = CreateTicket.execute("Single line ticket", @default_opts)

      assert ticket.title == "Single line ticket"
      assert ticket.body in ["", nil]
    end

    test "trims whitespace from title and body" do
      input = "  Whitespace title  \n  Whitespace body  "

      assert {:ok, ticket} = CreateTicket.execute(input, @default_opts)

      assert ticket.title == "Whitespace title"
      assert ticket.body == "Whitespace body"
    end

    test "returns error for empty body" do
      assert {:error, :body_required} = CreateTicket.execute("", @default_opts)
    end

    test "returns error for whitespace-only body" do
      assert {:error, :body_required} = CreateTicket.execute("   \n  ", @default_opts)
    end

    test "returns error for nil body" do
      assert {:error, :body_required} = CreateTicket.execute(nil, @default_opts)
    end

    test "assigns a negative temporary number" do
      assert {:ok, ticket} = CreateTicket.execute("Test ticket", @default_opts)

      assert ticket.number < 0
    end

    test "generates unique numbers for concurrent inserts" do
      results =
        1..5
        |> Enum.map(fn i ->
          CreateTicket.execute("Ticket #{i}", @default_opts)
        end)

      numbers = Enum.map(results, fn {:ok, t} -> t.number end)
      assert length(Enum.uniq(numbers)) == 5
    end

    test "emits TicketCreated domain event on success" do
      TestEventBus.start_global()

      assert {:ok, ticket} =
               CreateTicket.execute("Event test ticket\nWith a body", @default_opts)

      events = TestEventBus.get_events()
      assert [%TicketCreated{} = event] = events
      assert event.ticket_id == ticket.id
      assert event.title == "Event test ticket"
      assert event.body == "With a body"
      assert event.aggregate_id == to_string(ticket.id)
      assert event.actor_id == @actor_id
    end

    test "does not emit event on validation failure" do
      TestEventBus.start_global()

      assert {:error, :body_required} = CreateTicket.execute("", @default_opts)

      assert TestEventBus.get_events() == []
    end

    test "assigns a position to the new ticket" do
      assert {:ok, ticket} = CreateTicket.execute("Positioned ticket", @default_opts)

      assert is_integer(ticket.position)
    end
  end
end
