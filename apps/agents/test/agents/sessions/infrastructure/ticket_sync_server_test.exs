defmodule Agents.Sessions.Infrastructure.TicketSyncServerTest do
  use Agents.DataCase, async: false

  alias Agents.Repo
  alias Agents.Sessions.Infrastructure.Repositories.ProjectTicketRepository
  alias Agents.Sessions.Infrastructure.Schemas.ProjectTicketSchema
  alias Agents.Sessions.Infrastructure.TicketSyncServer
  alias Agents.Test.TicketSyncServerTestClient

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
      Process.sleep(50)

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
      Process.sleep(50)

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
      Process.sleep(50)
      parent_a = Repo.get_by!(ProjectTicketSchema, number: 400)
      child_first = Repo.get_by!(ProjectTicketSchema, number: 402)
      assert child_first.parent_ticket_id == parent_a.id

      send(server, :poll)
      Process.sleep(50)
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
      Process.sleep(50)

      ticket_a = Repo.get_by!(ProjectTicketSchema, number: 500)
      ticket_b = Repo.get_by!(ProjectTicketSchema, number: 501)

      refute ticket_a.parent_ticket_id == ticket_b.id and ticket_b.parent_ticket_id == ticket_a.id
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
