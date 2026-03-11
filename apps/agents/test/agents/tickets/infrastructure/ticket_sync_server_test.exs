defmodule Agents.Tickets.Infrastructure.TicketSyncServerTest do
  use Agents.DataCase, async: false

  import Ecto.Query

  alias Agents.Repo
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository
  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema
  alias Agents.Tickets.Infrastructure.Schemas.TicketLifecycleEventSchema
  alias Agents.Tickets.Infrastructure.TicketSyncServer
  alias Agents.Test.TicketSyncServerTestClient

  @topic "sessions:tickets"

  setup do
    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, @topic)
    :ok
  end

  describe "poll sync hierarchy resolution" do
    test "poll links sub-issues under their parent" do
      server =
        start_sync_server([
          {:ok,
           [
             %{number: 382, title: "Parent", labels: [], sub_issue_numbers: [383]},
             %{number: 383, title: "Child", labels: [], sub_issue_numbers: []}
           ]}
        ])

      send(server, :poll)
      assert_receive {:tickets_synced, _}, 5_000

      parent = Repo.get_by!(ProjectTicketSchema, number: 382)
      child = Repo.get_by!(ProjectTicketSchema, number: 383)

      assert child.parent_ticket_id == parent.id
    end

    test "deferred linking keeps child as root when parent does not persist" do
      server =
        start_sync_server([
          {:ok,
           [
             %{number: 390, title: nil, labels: [], sub_issue_numbers: [391]},
             %{number: 391, title: "Child", labels: [], sub_issue_numbers: []}
           ]}
        ])

      send(server, :poll)
      assert_receive {:tickets_synced, _}, 5_000

      child = Repo.get_by!(ProjectTicketSchema, number: 391)
      assert child.parent_ticket_id == nil
    end

    test "reparenting updates parent_ticket_id when sub-issue moves" do
      server =
        start_sync_server([
          {:ok,
           [
             %{number: 400, title: "Parent A", labels: [], sub_issue_numbers: [402]},
             %{number: 401, title: "Parent B", labels: [], sub_issue_numbers: []},
             %{number: 402, title: "Child", labels: [], sub_issue_numbers: []}
           ]},
          {:ok,
           [
             %{number: 400, title: "Parent A", labels: [], sub_issue_numbers: []},
             %{number: 401, title: "Parent B", labels: [], sub_issue_numbers: [402]},
             %{number: 402, title: "Child", labels: [], sub_issue_numbers: []}
           ]}
        ])

      send(server, :poll)
      assert_receive {:tickets_synced, _}, 5_000
      parent_a = Repo.get_by!(ProjectTicketSchema, number: 400)
      child_first = Repo.get_by!(ProjectTicketSchema, number: 402)
      assert child_first.parent_ticket_id == parent_a.id

      send(server, :poll)
      assert_receive {:tickets_synced, _}, 5_000
      parent_b = Repo.get_by!(ProjectTicketSchema, number: 401)
      child_second = Repo.get_by!(ProjectTicketSchema, number: 402)
      assert child_second.parent_ticket_id == parent_b.id
    end

    test "circular parent-child references are prevented" do
      server =
        start_sync_server([
          {:ok,
           [
             %{number: 500, title: "A", labels: [], sub_issue_numbers: [501]},
             %{number: 501, title: "B", labels: [], sub_issue_numbers: [500]}
           ]}
        ])

      send(server, :poll)
      assert_receive {:tickets_synced, _}, 5_000

      ticket_a = Repo.get_by!(ProjectTicketSchema, number: 500)
      ticket_b = Repo.get_by!(ProjectTicketSchema, number: 501)

      refute ticket_a.parent_ticket_id == ticket_b.id and ticket_b.parent_ticket_id == ticket_a.id
    end
  end

  describe "lifecycle event recording" do
    test "creates initial lifecycle event when syncing a new ticket" do
      server =
        start_sync_server([
          {:ok, [%{number: 1200, title: "New ticket", state: "open", labels: []}]}
        ])

      send(server, :poll)
      assert_receive {:tickets_synced, _}, 5_000

      ticket = Repo.get_by!(ProjectTicketSchema, number: 1200)

      event =
        Repo.one!(
          from(e in TicketLifecycleEventSchema,
            where: e.ticket_id == ^ticket.id,
            order_by: [asc: e.transitioned_at],
            limit: 1
          )
        )

      assert event.from_stage == nil
      assert event.to_stage == "open"
      assert event.trigger == "sync"
    end

    test "records a transition when ticket state changes across syncs" do
      server =
        start_sync_server([
          {:ok, [%{number: 1201, title: "Lifecycle", state: "open", labels: []}]},
          {:ok, [%{number: 1201, title: "Lifecycle", state: "closed", labels: []}]}
        ])

      send(server, :poll)
      assert_receive {:tickets_synced, _}, 5_000

      send(server, :poll)
      assert_receive {:tickets_synced, _}, 5_000

      ticket = Repo.get_by!(ProjectTicketSchema, number: 1201)

      events =
        Repo.all(
          from(e in TicketLifecycleEventSchema,
            where: e.ticket_id == ^ticket.id,
            order_by: [asc: e.transitioned_at, asc: e.id]
          )
        )

      assert Enum.map(events, &{&1.from_stage, &1.to_stage, &1.trigger}) == [
               {nil, "open", "sync"},
               {"open", "closed", "sync"}
             ]
    end

    test "does not create duplicate lifecycle event when state does not change" do
      server =
        start_sync_server([
          {:ok, [%{number: 1202, title: "Stable", state: "open", labels: []}]},
          {:ok, [%{number: 1202, title: "Stable", state: "open", labels: []}]}
        ])

      send(server, :poll)
      assert_receive {:tickets_synced, _}, 5_000

      send(server, :poll)
      assert_receive {:tickets_synced, _}, 5_000

      ticket = Repo.get_by!(ProjectTicketSchema, number: 1202)

      count =
        Repo.aggregate(
          from(e in TicketLifecycleEventSchema, where: e.ticket_id == ^ticket.id),
          :count,
          :id
        )

      assert count == 1
    end
  end

  defp start_sync_server(responses) do
    start_supervised!({TicketSyncServerTestClient, responses: responses})

    server_name = String.to_atom("ticket_sync_server_test_#{System.unique_integer([:positive])}")

    start_supervised!({
      TicketSyncServer,
      [
        name: server_name,
        client: TicketSyncServerTestClient,
        ticket_repo: ProjectTicketRepository
      ]
    })
  end
end
