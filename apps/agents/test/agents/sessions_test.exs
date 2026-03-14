defmodule Agents.SessionsTest do
  use Agents.DataCase, async: true

  alias Agents.Sessions
  alias Agents.Sessions.Domain.Entities.Task
  alias Agents.Tickets
  alias Agents.Tickets.Domain.Entities.Ticket
  alias Agents.Tickets.Infrastructure.Schemas.ProjectTicketSchema
  alias Agents.Repo

  import Agents.Test.AccountsFixtures
  import Agents.SessionsFixtures

  describe "create_task/2" do
    test "creates a task and returns current status from DB" do
      user = user_fixture()

      assert {:ok, %Task{} = task} =
               Sessions.create_task(
                 %{instruction: "Write tests", user_id: user.id},
                 task_runner_starter: fn _id, _opts -> {:ok, self()} end
               )

      assert task.instruction == "Write tests"
      # Task is created as "queued" but may be immediately promoted to
      # "pending" by the queue manager. The facade re-reads from DB after
      # notify_task_queued so the returned status reflects the current state.
      assert task.status in ["queued", "pending"]
      assert task.user_id == user.id
    end

    test "returns error for blank instruction" do
      user = user_fixture()

      assert {:error, :instruction_required} =
               Sessions.create_task(%{instruction: "", user_id: user.id})
    end
  end

  describe "get_task/2" do
    test "returns domain entity for owned task" do
      user = user_fixture()
      task_schema = task_fixture(%{user_id: user.id})

      assert {:ok, %Task{} = task} = Sessions.get_task(task_schema.id, user.id)
      assert task.id == task_schema.id
    end

    test "returns not_found for other user's task" do
      user = user_fixture()
      other_user = user_fixture()
      task_schema = task_fixture(%{user_id: other_user.id})

      assert {:error, :not_found} = Sessions.get_task(task_schema.id, user.id)
    end
  end

  describe "list_tasks/1" do
    test "returns list of domain entities" do
      user = user_fixture()
      task_fixture(%{user_id: user.id, instruction: "Task 1"})
      task_fixture(%{user_id: user.id, instruction: "Task 2"})

      tasks = Sessions.list_tasks(user.id)

      assert length(tasks) == 2
      assert Enum.all?(tasks, &match?(%Task{}, &1))
    end

    test "returns empty list for user with no tasks" do
      user = user_fixture()
      assert [] == Sessions.list_tasks(user.id)
    end
  end

  describe "cancel_task/2" do
    test "returns error for non-existent task" do
      user = user_fixture()
      assert {:error, :not_found} = Sessions.cancel_task(Ecto.UUID.generate(), user.id)
    end

    test "returns error for completed task" do
      user = user_fixture()
      task = task_fixture(%{user_id: user.id, status: "completed"})

      assert {:error, :not_cancellable} = Sessions.cancel_task(task.id, user.id)
    end
  end

  describe "delete_task/2" do
    test "deletes a completed task" do
      user = user_fixture()
      task = task_fixture(%{user_id: user.id, status: "completed"})

      assert :ok = Sessions.delete_task(task.id, user.id)
      assert {:error, :not_found} = Sessions.get_task(task.id, user.id)
    end

    test "deletes a failed task" do
      user = user_fixture()
      task = task_fixture(%{user_id: user.id, status: "failed"})

      assert :ok = Sessions.delete_task(task.id, user.id)
      assert {:error, :not_found} = Sessions.get_task(task.id, user.id)
    end

    test "deletes a queued task" do
      user = user_fixture()
      task = task_fixture(%{user_id: user.id, status: "queued"})

      assert :ok = Sessions.delete_task(task.id, user.id)
      assert {:error, :not_found} = Sessions.get_task(task.id, user.id)
    end

    test "returns error for running task" do
      user = user_fixture()
      task = task_fixture(%{user_id: user.id, status: "running"})

      assert {:error, :not_deletable} = Sessions.delete_task(task.id, user.id)
    end

    test "returns error for non-existent task" do
      user = user_fixture()
      assert {:error, :not_found} = Sessions.delete_task(Ecto.UUID.generate(), user.id)
    end

    test "returns error for other user's task" do
      user = user_fixture()
      other_user = user_fixture()
      task = task_fixture(%{user_id: other_user.id, status: "completed"})

      assert {:error, :not_found} = Sessions.delete_task(task.id, user.id)
    end
  end

  describe "list_sessions/2" do
    test "returns sessions grouped by container_id" do
      user = user_fixture()
      container_a = "container-aaa"
      container_b = "container-bbb"

      task_fixture(%{
        user_id: user.id,
        instruction: "First task in A",
        container_id: container_a,
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Second task in A",
        container_id: container_a,
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Only task in B",
        container_id: container_b,
        status: "completed"
      })

      sessions = Sessions.list_sessions(user.id)

      assert length(sessions) == 2

      session_a = Enum.find(sessions, &(&1.container_id == container_a))
      session_b = Enum.find(sessions, &(&1.container_id == container_b))

      assert session_a.task_count == 2
      assert session_a.title == "First task in A"

      assert session_b.task_count == 1
      assert session_b.title == "Only task in B"
      assert session_b.latest_status == "completed"
    end

    test "returns empty list for user with no sessions" do
      user = user_fixture()
      assert [] == Sessions.list_sessions(user.id)
    end

    test "excludes tasks without container_id" do
      user = user_fixture()

      # Task with no container_id — should not appear in sessions
      task_fixture(%{user_id: user.id, instruction: "No container"})

      # Task with a container_id — should appear
      task_fixture(%{
        user_id: user.id,
        instruction: "With container",
        container_id: "container-xyz"
      })

      sessions = Sessions.list_sessions(user.id)

      assert length(sessions) == 1
      assert hd(sessions).container_id == "container-xyz"
    end
  end

  describe "get_container_stats/2" do
    test "delegates to container provider" do
      {:module, mock_mod, _, _} =
        defmodule :"Agents.SessionsTest.MockContainerStats.#{System.unique_integer([:positive])}" do
          def stats("container-123") do
            {:ok, %{cpu_percent: 25.0, memory_usage: 100, memory_limit: 200}}
          end
        end

      assert {:ok, stats} =
               Sessions.get_container_stats("container-123", container_provider: mock_mod)

      assert stats.cpu_percent == 25.0
      assert stats.memory_usage == 100
      assert stats.memory_limit == 200
    end

    test "returns error for unknown container" do
      {:module, mock_mod, _, _} =
        defmodule :"Agents.SessionsTest.MockContainerStatsError.#{System.unique_integer([:positive])}" do
          def stats(_container_id) do
            {:error, :not_found}
          end
        end

      assert {:error, :not_found} =
               Sessions.get_container_stats("unknown-container", container_provider: mock_mod)
    end
  end

  describe "answer_question/3" do
    test "returns :task_not_running when no runner registered" do
      task_id = Ecto.UUID.generate()
      request_id = "req-123"
      answers = [["Option A"]]

      assert {:error, :task_not_running} =
               Sessions.answer_question(task_id, request_id, answers)
    end
  end

  describe "reject_question/2" do
    test "returns :task_not_running when no runner registered" do
      task_id = Ecto.UUID.generate()
      request_id = "req-456"

      assert {:error, :task_not_running} =
               Sessions.reject_question(task_id, request_id)
    end
  end

  describe "send_message/2" do
    test "returns :task_not_running when no runner registered" do
      task_id = Ecto.UUID.generate()

      assert {:error, :task_not_running} =
               Sessions.send_message(task_id, "hello")
    end

    test "restarts runner in resume mode when registry process is missing" do
      task_id = Ecto.UUID.generate()
      test_pid = self()

      task_repo = %{
        get_task: fn ^task_id ->
          %{
            id: task_id,
            instruction: "Original task",
            container_id: "container-123",
            session_id: "session-123"
          }
        end
      }

      starter = fn started_task_id, runner_opts ->
        send(test_pid, {:runner_started, started_task_id, runner_opts})
        {:ok, self()}
      end

      # Lightweight mock module with only get_task/1 expected by send_message fallback
      {:module, repo_mod, _, _} =
        defmodule :"Agents.SessionsTest.MockTaskRepo.#{System.unique_integer([:positive])}" do
          def set_impl(fun), do: :persistent_term.put({__MODULE__, :get_task}, fun)
          def get_task(task_id), do: :persistent_term.get({__MODULE__, :get_task}).(task_id)
        end

      repo_mod.set_impl(task_repo.get_task)

      assert :ok =
               Sessions.send_message(task_id, "follow up",
                 task_repo: repo_mod,
                 task_runner_starter: starter
               )

      assert_receive {:runner_started, ^task_id, runner_opts}
      assert runner_opts[:resume] == true
      assert runner_opts[:instruction] == "Original task"
      assert runner_opts[:prompt_instruction] == "follow up"
      assert runner_opts[:container_id] == "container-123"
      assert runner_opts[:session_id] == "session-123"
    end

    test "marks orphaned active tasks as failed when linkage is missing" do
      user = user_fixture()

      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "orphaned pending task",
          status: "pending",
          container_id: nil,
          session_id: nil
        })

      assert {:error, :task_not_running} = Sessions.send_message(task.id, "follow up")

      assert {:ok, refreshed} = Sessions.get_task(task.id, user.id)
      assert refreshed.status == "failed"
      assert refreshed.error == "Runner linkage missing"
    end

    test "does not restart cancelled tasks even when linkage exists" do
      task_id = Ecto.UUID.generate()
      test_pid = self()

      task_repo = %{
        get_task: fn ^task_id ->
          %{
            id: task_id,
            instruction: "cancelled task",
            status: "cancelled",
            container_id: "container-cancelled",
            session_id: "session-cancelled"
          }
        end
      }

      starter = fn started_task_id, runner_opts ->
        send(test_pid, {:runner_started, started_task_id, runner_opts})
        {:ok, self()}
      end

      {:module, repo_mod, _, _} =
        defmodule :"Agents.SessionsTest.MockTaskRepoCancelled.#{System.unique_integer([:positive])}" do
          def set_impl(fun), do: :persistent_term.put({__MODULE__, :get_task}, fun)
          def get_task(task_id), do: :persistent_term.get({__MODULE__, :get_task}).(task_id)
        end

      repo_mod.set_impl(task_repo.get_task)

      assert {:error, :task_not_running} =
               Sessions.send_message(task_id, "follow up",
                 task_repo: repo_mod,
                 task_runner_starter: starter
               )

      refute_receive {:runner_started, ^task_id, _runner_opts}
    end
  end

  describe "delete_session/3" do
    test "deletes all tasks for a container" do
      user = user_fixture()
      container_id = "container-to-delete"

      {:module, mock_mod, _, _} =
        defmodule :"Agents.SessionsTest.MockContainerRemove.#{System.unique_integer([:positive])}" do
          def remove(_container_id), do: :ok
        end

      task_fixture(%{
        user_id: user.id,
        instruction: "Task 1",
        container_id: container_id,
        status: "completed"
      })

      task_fixture(%{
        user_id: user.id,
        instruction: "Task 2",
        container_id: container_id,
        status: "completed"
      })

      assert :ok =
               Sessions.delete_session(container_id, user.id,
                 container_provider: mock_mod,
                 task_runner_cancel: fn _id -> :ok end
               )

      # All tasks for this container should be gone
      assert Sessions.list_sessions(user.id) == []
    end

    test "returns error for non-existent container" do
      user = user_fixture()

      assert {:error, :not_found} =
               Sessions.delete_session("non-existent-container", user.id)
    end
  end

  describe "resume_task/3" do
    test "preserves original instruction and requeues session" do
      user = user_fixture()
      container_id = "container-resume"
      session_id = "session-resume"

      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Original task",
          container_id: container_id,
          session_id: session_id,
          status: "completed"
        })

      assert {:ok, %Task{} = resumed} =
               Sessions.resume_task(
                 task.id,
                 %{instruction: "Follow-up task", user_id: user.id},
                 task_runner_starter: fn _id, _opts -> {:ok, self()} end
               )

      # Same task record, updated in place
      assert resumed.id == task.id
      assert resumed.instruction == "Original task"
      assert resumed.status == "queued"
      assert resumed.container_id == container_id
      assert resumed.session_id == session_id
      assert resumed.user_id == user.id
    end

    test "returns error for non-existent task" do
      user = user_fixture()

      assert {:error, :not_found} =
               Sessions.resume_task(
                 Ecto.UUID.generate(),
                 %{instruction: "Follow-up", user_id: user.id},
                 task_runner_starter: fn _id, _opts -> {:ok, self()} end
               )
    end

    test "returns error for active task" do
      user = user_fixture()

      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Still running",
          container_id: "container-active",
          session_id: "session-active",
          status: "running"
        })

      assert {:error, :already_active} =
               Sessions.resume_task(
                 task.id,
                 %{instruction: "Follow-up", user_id: user.id},
                 task_runner_starter: fn _id, _opts -> {:ok, self()} end
               )
    end

    test "returns error for task without container" do
      user = user_fixture()

      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "No container task",
          status: "completed"
        })

      assert {:error, :no_container} =
               Sessions.resume_task(
                 task.id,
                 %{instruction: "Follow-up", user_id: user.id},
                 task_runner_starter: fn _id, _opts -> {:ok, self()} end
               )
    end
  end

  describe "refresh_auth_and_resume/3" do
    test "returns error for non-existent task" do
      user = user_fixture()

      assert {:error, :not_found} =
               Sessions.refresh_auth_and_resume(Ecto.UUID.generate(), user.id,
                 task_runner_starter: fn _id, _opts -> {:ok, self()} end,
                 resume_fn: fn _id, _attrs, _opts -> {:ok, %Task{}} end
               )
    end

    test "returns error for non-failed task" do
      user = user_fixture()

      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Completed task",
          container_id: "container-auth",
          status: "completed"
        })

      assert {:error, :not_resumable} =
               Sessions.refresh_auth_and_resume(task.id, user.id,
                 task_runner_starter: fn _id, _opts -> {:ok, self()} end,
                 resume_fn: fn _id, _attrs, _opts -> {:ok, %Task{}} end
               )
    end

    test "returns error for failed task without container" do
      user = user_fixture()

      task =
        task_fixture(%{
          user_id: user.id,
          instruction: "Failed without container",
          status: "failed"
        })

      assert {:error, :no_container} =
               Sessions.refresh_auth_and_resume(task.id, user.id,
                 task_runner_starter: fn _id, _opts -> {:ok, self()} end,
                 resume_fn: fn _id, _attrs, _opts -> {:ok, %Task{}} end
               )
    end
  end

  describe "notify_task_terminal_status/4" do
    test "ensures queue manager and forwards completed notifications" do
      user = user_fixture()
      task = task_fixture(%{user_id: user.id, status: "completed"})
      test_pid = self()

      {:module, supervisor_mod, _, _} =
        defmodule :"Agents.SessionsTest.MockQueueSupervisor.#{System.unique_integer([:positive])}" do
          def set_test_pid(pid), do: :persistent_term.put({__MODULE__, :test_pid}, pid)

          def ensure_started(user_id) do
            send(:persistent_term.get({__MODULE__, :test_pid}), {:queue_manager_ensured, user_id})
            {:ok, self()}
          end
        end

      {:module, queue_manager_mod, _, _} =
        defmodule :"Agents.SessionsTest.MockQueueManager.#{System.unique_integer([:positive])}" do
          def set_test_pid(pid), do: :persistent_term.put({__MODULE__, :test_pid}, pid)

          def notify_task_completed(user_id, task_id) do
            send(
              :persistent_term.get({__MODULE__, :test_pid}),
              {:queue_notified, :completed, user_id, task_id}
            )

            :ok
          end

          def notify_task_failed(_user_id, _task_id), do: :ok
          def notify_task_cancelled(_user_id, _task_id), do: :ok
        end

      supervisor_mod.set_test_pid(test_pid)
      queue_manager_mod.set_test_pid(test_pid)

      assert :ok =
               Sessions.notify_task_terminal_status(user.id, task.id, :completed,
                 queue_orchestrator_supervisor: supervisor_mod,
                 queue_orchestrator: queue_manager_mod
               )

      user_id = user.id
      task_id = task.id
      assert_receive {:queue_manager_ensured, ^user_id}
      assert_receive {:queue_notified, :completed, ^user_id, ^task_id}
    end

    test "returns :ok when queue manager supervisor is unavailable" do
      user = user_fixture()
      task = task_fixture(%{user_id: user.id, status: "failed"})

      {:module, supervisor_mod, _, _} =
        defmodule :"Agents.SessionsTest.MockQueueSupervisorUnavailable.#{System.unique_integer([:positive])}" do
          def ensure_started(_user_id), do: raise("queue manager unavailable")
        end

      assert :ok =
               Sessions.notify_task_terminal_status(user.id, task.id, :failed,
                 queue_orchestrator_supervisor: supervisor_mod
               )
    end
  end

  describe "ticket sync projection" do
    test "extract_ticket_number/1 handles hashtag and ticket prefixes" do
      assert Tickets.extract_ticket_number("Implement #306 in the session panel") == 306
      assert Tickets.extract_ticket_number("please work on ticket 412 next") == 412
      assert Tickets.extract_ticket_number("no ticket ref") == nil
    end

    test "list_project_tickets/2 enriches tickets with associated session state" do
      user = user_fixture()

      _task_306 =
        task_fixture(%{
          user_id: user.id,
          instruction: "Work on #306 from backlog",
          container_id: "container-306",
          status: "running"
        })

      task_410 =
        task_fixture(%{
          user_id: user.id,
          instruction: "ship ticket 410 fixes",
          container_id: "container-410",
          status: "completed"
        })

      alias Agents.Tickets.Infrastructure.Repositories.ProjectTicketRepository

      {:ok, _} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 306,
          title: "Ticket 306",
          body: "Implement queue-first create flow",
          labels: [],
          state: "open"
        })

      {:ok, _} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 410,
          title: "Ticket 410",
          body: "Ship the browser feature files",
          labels: [],
          state: "open"
        })

      {:ok, _} =
        ProjectTicketRepository.sync_remote_ticket(%{
          number: 999,
          title: "Unlinked",
          labels: [],
          state: "open"
        })

      # Running tasks match via regex fallback; terminal tasks require a
      # persisted association (task_id FK). Link ticket 410 via the DB so
      # enrichment finds the completed task through the persisted path.
      {:ok, _} = Tickets.link_ticket_to_task(410, task_410.id)

      result = Tickets.list_project_tickets(user.id)

      assert Enum.all?(result, &match?(%Ticket{}, &1))

      ticket_306 = Enum.find(result, &(&1.number == 306))
      ticket_410 = Enum.find(result, &(&1.number == 410))
      ticket_999 = Enum.find(result, &(&1.number == 999))

      assert ticket_306.session_state == "running"
      assert ticket_306.associated_container_id == "container-306"
      assert ticket_306.body == "Implement queue-first create flow"

      assert ticket_410.session_state == "completed"
      assert ticket_410.associated_container_id == "container-410"
      assert ticket_410.body == "Ship the browser feature files"

      assert ticket_999.session_state == "idle"
      assert ticket_999.associated_container_id == nil
    end

    test "list_project_tickets/1 reads persisted tickets from DB" do
      user = user_fixture()

      insert_project_ticket(%{
        number: 306,
        title: "Ticket 306",
        status: "Backlog",
        labels: ["agents"]
      })

      insert_project_ticket(%{number: 410, title: "Ticket 410", status: "Ready", labels: []})
      insert_project_ticket(%{number: 999, title: "Another ticket", status: "Done", labels: []})

      task_fixture(%{
        user_id: user.id,
        instruction: "Work on #306 from backlog",
        container_id: "container-306",
        status: "running"
      })

      result = Tickets.list_project_tickets(user.id)

      # All open issues are returned (no status filtering)
      assert length(result) == 3
      assert Enum.all?(result, &match?(%Ticket{}, &1))
      assert Enum.find(result, &(&1.number == 306)).session_state == "running"
      assert Enum.find(result, &(&1.number == 410)).session_state == "idle"
      assert Enum.find(result, &(&1.number == 999)).session_state == "idle"
    end

    test "list_project_tickets/1 returns root tickets with enriched nested sub_tickets" do
      user = user_fixture()

      parent = insert_project_ticket(%{number: 500, title: "Parent ticket"})

      _child =
        insert_project_ticket(%{number: 501, title: "Child ticket", parent_ticket_id: parent.id})

      task_fixture(%{
        user_id: user.id,
        instruction: "continue work on #501",
        container_id: "container-501",
        status: "running"
      })

      [parent_ticket] = Tickets.list_project_tickets(user.id)

      assert %Ticket{} = parent_ticket
      assert parent_ticket.number == 500
      assert length(parent_ticket.sub_tickets) == 1

      [sub_ticket] = parent_ticket.sub_tickets
      assert %Ticket{} = sub_ticket
      assert sub_ticket.number == 501
      assert sub_ticket.session_state == "running"
      assert sub_ticket.associated_container_id == "container-501"
    end
  end

  defp insert_project_ticket(attrs) do
    attrs =
      %{
        number: attrs[:number],
        title: attrs[:title] || "Ticket #{attrs[:number]}",
        status: attrs[:status] || "Backlog",
        priority: attrs[:priority],
        labels: attrs[:labels] || [],
        url: attrs[:url] || "https://github.com/platform-q-ai/perme8/issues/#{attrs[:number]}",
        sync_state: attrs[:sync_state] || "synced",
        created_at: attrs[:created_at] || DateTime.utc_now() |> DateTime.truncate(:second),
        parent_ticket_id: attrs[:parent_ticket_id]
      }

    {:ok, ticket} =
      %ProjectTicketSchema{}
      |> ProjectTicketSchema.changeset(attrs)
      |> Repo.insert()

    ticket
  end

  describe "restart_orphaned_task/3" do
    test "restarts a task that was orphaned by server restart" do
      user = user_fixture()
      orphan_prefix = Agents.Sessions.Infrastructure.OrphanRecovery.orphan_error_prefix()

      task =
        task_fixture(%{
          user_id: user.id,
          status: "failed",
          error: "#{orphan_prefix} — no TaskRunner process was active for this task",
          container_id: "c-orphan-restart",
          session_id: "s-orphan-restart"
        })

      assert {:ok, restarted} =
               Sessions.restart_orphaned_task(task.id, user.id,
                 task_runner_starter: fn _id, _opts -> {:ok, self()} end
               )

      assert restarted.instruction == task.instruction
    end

    test "returns :not_found for non-existent task" do
      user = user_fixture()

      assert {:error, :not_found} =
               Sessions.restart_orphaned_task(Ecto.UUID.generate(), user.id)
    end

    test "returns :not_orphaned for task with wrong status" do
      user = user_fixture()
      task = task_fixture(%{user_id: user.id, status: "completed"})

      assert {:error, :not_orphaned} =
               Sessions.restart_orphaned_task(task.id, user.id)
    end

    test "returns :not_orphaned for failed task with different error" do
      user = user_fixture()

      task =
        task_fixture(%{
          user_id: user.id,
          status: "failed",
          error: "Container crashed unexpectedly"
        })

      assert {:error, :not_orphaned} =
               Sessions.restart_orphaned_task(task.id, user.id)
    end

    test "returns :not_orphaned for failed task with nil error" do
      user = user_fixture()
      task = task_fixture(%{user_id: user.id, status: "failed", error: nil})

      assert {:error, :not_orphaned} =
               Sessions.restart_orphaned_task(task.id, user.id)
    end
  end
end
