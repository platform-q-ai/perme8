defmodule AgentsWeb.DashboardLive.TicketSessionLinkerTest do
  use AgentsWeb.ConnCase, async: true

  import Agents.SessionsFixtures

  alias AgentsWeb.DashboardLive.TicketSessionLinker
  alias Agents.Tickets
  alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository

  # Build a minimal Phoenix.LiveView.Socket with the assigns TicketSessionLinker needs.
  defp build_socket(assigns_override) do
    assigns =
      %{
        tickets: [],
        tasks_snapshot: [],
        current_scope: %{user: %{id: "test-user-id"}},
        __changed__: %{}
      }
      |> Map.merge(assigns_override)

    %Phoenix.LiveView.Socket{assigns: assigns}
  end

  defp create_ticket!(attrs) do
    {:ok, ticket} =
      ProjectTicketRepository.sync_remote_ticket(
        Map.merge(
          %{
            status: "Ready",
            priority: "Need",
            size: "M",
            labels: []
          },
          attrs
        )
      )

    ticket
  end

  describe "link_and_refresh/2" do
    setup %{} do
      user = Jarga.AccountsFixtures.user_fixture()
      %{user: user}
    end

    test "persists FK and reloads tickets from DB when task references a ticket", %{user: user} do
      create_ticket!(%{number: 42, title: "Fix login bug"})

      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "pick up ticket #42 using the relevant skill",
          container_id: "c-42",
          status: "running"
        })

      socket =
        build_socket(%{
          tickets: Tickets.list_project_tickets(user.id),
          tasks_snapshot: [],
          current_scope: %{user: user}
        })

      updated_socket = TicketSessionLinker.link_and_refresh(socket, task)

      # The ticket should now have the task's ID as associated_task_id
      ticket_42 =
        updated_socket.assigns.tickets
        |> List.flatten()
        |> Enum.find(&(&1.number == 42))

      assert ticket_42.associated_task_id == task.id

      # tasks_snapshot should include the task
      assert Enum.any?(updated_socket.assigns.tasks_snapshot, &(&1.id == task.id))
    end

    test "does not call link when task instruction has no ticket reference", %{user: user} do
      create_ticket!(%{number: 99, title: "Unrelated ticket"})

      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Write tests for the login flow",
          container_id: "c-no-ref",
          status: "running"
        })

      socket =
        build_socket(%{
          tickets: Tickets.list_project_tickets(user.id),
          tasks_snapshot: [],
          current_scope: %{user: user}
        })

      updated_socket = TicketSessionLinker.link_and_refresh(socket, task)

      # Ticket 99 should NOT be linked
      ticket_99 =
        updated_socket.assigns.tickets
        |> List.flatten()
        |> Enum.find(&(&1.number == 99))

      assert is_nil(ticket_99.associated_task_id)

      # tasks_snapshot should still include the task (upserted)
      assert Enum.any?(updated_socket.assigns.tasks_snapshot, &(&1.id == task.id))
    end

    test "rescues exceptions from link_ticket_to_task and returns valid socket", %{user: user} do
      # Create a task referencing a ticket that does NOT exist in DB
      # link_ticket_to_task will fail but should not crash
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "pick up ticket #9999 fix it",
          container_id: "c-9999",
          status: "running"
        })

      socket =
        build_socket(%{
          tickets: [],
          tasks_snapshot: [],
          current_scope: %{user: user}
        })

      # Should not raise
      updated_socket = TicketSessionLinker.link_and_refresh(socket, task)

      # Socket should still be valid with the task upserted into snapshot
      assert is_list(updated_socket.assigns.tickets)
      assert Enum.any?(updated_socket.assigns.tasks_snapshot, &(&1.id == task.id))
    end
  end

  describe "unlink_and_refresh/2" do
    setup %{} do
      user = Jarga.AccountsFixtures.user_fixture()
      %{user: user}
    end

    test "clears FK and reloads tickets from DB", %{user: user} do
      create_ticket!(%{number: 55, title: "Bug to fix"})

      # Use a cancelled task — in real usage, unlink follows do_cancel_task
      # which sets the task to terminal status. Terminal tasks are filtered
      # from the regex fallback so the unlinked ticket won't re-associate.
      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "pick up ticket #55",
          container_id: "c-55",
          status: "cancelled"
        })

      # Link the ticket first
      {:ok, _} = Tickets.link_ticket_to_task(55, task.id)

      socket =
        build_socket(%{
          tickets: Tickets.list_project_tickets(user.id, tasks: [task]),
          tasks_snapshot: [task],
          current_scope: %{user: user}
        })

      # Verify linked before unlink (persisted FK still associates it)
      ticket_55_before =
        socket.assigns.tickets
        |> List.flatten()
        |> Enum.find(&(&1.number == 55))

      assert ticket_55_before.associated_task_id == task.id

      # Unlink — clears the FK in DB
      updated_socket = TicketSessionLinker.unlink_and_refresh(socket, 55)

      ticket_55_after =
        updated_socket.assigns.tickets
        |> List.flatten()
        |> Enum.find(&(&1.number == 55))

      # With FK cleared and task terminal, the ticket is no longer associated
      assert is_nil(ticket_55_after.associated_task_id)
    end
  end

  describe "cleanup_and_refresh/3" do
    test "removes tasks for container and re-enriches tickets" do
      alias Agents.Tickets.Domain.Entities.Ticket

      task_a = %{
        id: "task-a",
        container_id: "c-remove",
        instruction: "work on #10",
        status: "running",
        lifecycle_state: nil
      }

      task_b = %{
        id: "task-b",
        container_id: "c-keep",
        instruction: "work on #20",
        status: "running",
        lifecycle_state: nil
      }

      tickets = [
        Ticket.new(%{number: 10, title: "Ticket 10"}),
        Ticket.new(%{number: 20, title: "Ticket 20"})
      ]

      tasks_snapshot = [task_a, task_b]

      {cleaned_snapshot, enriched_tickets} =
        TicketSessionLinker.cleanup_and_refresh(tasks_snapshot, tickets, "c-remove")

      # task_a should be removed, task_b should remain
      assert length(cleaned_snapshot) == 1
      assert hd(cleaned_snapshot).id == "task-b"

      # Ticket 10 should be idle (its task was removed)
      ticket_10 = Enum.find(enriched_tickets, &(&1.number == 10))
      assert ticket_10.session_state == "idle" or is_nil(ticket_10.session_state)

      # Ticket 20 should still have its session state from task_b
      ticket_20 = Enum.find(enriched_tickets, &(&1.number == 20))
      assert ticket_20.associated_task_id == "task-b"
    end
  end

  describe "refresh_tickets/1" do
    setup %{} do
      user = Jarga.AccountsFixtures.user_fixture()
      %{user: user}
    end

    test "reloads tickets from DB with current tasks_snapshot", %{user: user} do
      create_ticket!(%{number: 77, title: "Feature request"})

      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "pick up ticket #77",
          container_id: "c-77",
          status: "running"
        })

      # Link in DB
      {:ok, _} = Tickets.link_ticket_to_task(77, task.id)

      # Start with stale tickets (no association)
      socket =
        build_socket(%{
          tickets: [],
          tasks_snapshot: [task],
          current_scope: %{user: user}
        })

      updated_socket = TicketSessionLinker.refresh_tickets(socket)

      ticket_77 =
        updated_socket.assigns.tickets
        |> List.flatten()
        |> Enum.find(&(&1.number == 77))

      assert ticket_77 != nil
      assert ticket_77.associated_task_id == task.id
    end
  end
end
