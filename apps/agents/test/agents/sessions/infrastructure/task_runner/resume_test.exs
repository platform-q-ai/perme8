defmodule Agents.Sessions.Infrastructure.TaskRunner.ResumeTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Sessions.Infrastructure.TaskRunner

  setup :set_mox_global
  setup :verify_on_exit!

  alias Agents.Test.AccountsFixtures
  alias Agents.SessionsFixtures

  setup do
    user = AccountsFixtures.user_fixture()

    task =
      SessionsFixtures.task_fixture(%{
        user_id: user.id,
        container_id: "existing-container",
        session_id: "existing-session"
      })

    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")

    {:ok, task: task}
  end

  @default_opts [
    container_provider: Agents.Mocks.ContainerProviderMock,
    opencode_client: Agents.Mocks.OpencodeClientMock,
    task_repo: Agents.Mocks.TaskRepositoryMock,
    pubsub: Perme8.Events.PubSub
  ]

  test "resume path restarts container, skips session creation, and sends prompt", %{task: task} do
    test_pid = self()

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, attrs ->
      if attrs[:status] do
        send(test_pid, {:status_updated, attrs.status})
      end

      {:ok, task}
    end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:restart, fn "existing-container" ->
      {:ok, %{port: 5000}}
    end)
    |> stub(:stop, fn _id -> :ok end)

    Agents.Mocks.OpencodeClientMock
    |> expect(:health, fn _url -> :ok end)
    |> expect(:subscribe_events, fn _url, runner_pid ->
      # Simulate completion after prompt
      spawn(fn ->
        Process.sleep(100)

        send(runner_pid, {
          :opencode_event,
          %{
            "type" => "session.status",
            "properties" => %{"sessionID" => "existing-session", "status" => %{"type" => "busy"}}
          }
        })

        Process.sleep(50)

        send(runner_pid, {
          :opencode_event,
          %{
            "type" => "session.status",
            "properties" => %{"sessionID" => "existing-session", "status" => %{"type" => "idle"}}
          }
        })
      end)

      {:ok, self()}
    end)
    |> expect(:send_prompt_async, fn _url, "existing-session", _parts, _opts ->
      send(test_pid, :prompt_sent)
      :ok
    end)

    resume_opts =
      @default_opts ++
        [
          resume: true,
          container_id: "existing-container",
          session_id: "existing-session"
        ]

    {:ok, pid} = GenServer.start(TaskRunner, {task.id, resume_opts})
    ref = Process.monitor(pid)

    assert_receive :prompt_sent, 5000
    assert_receive {:task_status_changed, _, "starting"}, 5000
    assert_receive {:task_status_changed, _, "running"}, 5000
    assert_receive {:task_status_changed, _, "completed"}, 5000
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5_000
  end

  test "resume path fails when container restart fails", %{task: task} do
    test_pid = self()

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, %{status: "failed", error: error} ->
      send(test_pid, {:failed, error})
      {:ok, task}
    end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:restart, fn "existing-container" ->
      {:error, :container_not_found}
    end)
    |> stub(:stop, fn _id -> :ok end)

    resume_opts =
      @default_opts ++
        [
          resume: true,
          container_id: "existing-container",
          session_id: "existing-session"
        ]

    {:ok, pid} = GenServer.start(TaskRunner, {task.id, resume_opts})
    ref = Process.monitor(pid)

    assert_receive {:failed, error}, 5000
    assert String.contains?(error, "Container restart failed")
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5_000
  end

  test "resume path preserves prior-run todos and prepends them to new todo events", %{
    task: task
  } do
    test_pid = self()
    task_id = task.id

    # Task has prior-run todos stored in DB
    prior_todos = %{
      "items" => [
        %{"id" => "old-1", "title" => "Setup", "status" => "completed", "position" => 0},
        %{"id" => "old-2", "title" => "Implement", "status" => "completed", "position" => 1}
      ]
    }

    task_with_todos = %{task | todo_items: prior_todos}

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task_with_todos end)
    |> stub(:update_task_status, fn _task, attrs ->
      send(test_pid, {:task_update, attrs})
      {:ok, task_with_todos}
    end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:restart, fn "existing-container" -> {:ok, %{port: 5000}} end)
    |> stub(:stop, fn _id -> :ok end)

    # New run sends its own todos, then completes
    new_run_todos = [
      %{"id" => "new-1", "content" => "Review", "status" => "in_progress"},
      %{"id" => "new-2", "content" => "Test", "status" => "pending"}
    ]

    Agents.Mocks.OpencodeClientMock
    |> expect(:health, fn _url -> :ok end)
    |> expect(:subscribe_events, fn _url, runner_pid ->
      spawn(fn ->
        Process.sleep(50)

        send(
          runner_pid,
          {:opencode_event,
           %{"type" => "todo.updated", "properties" => %{"todos" => new_run_todos}}}
        )

        Process.sleep(50)

        send(
          runner_pid,
          {:opencode_event,
           %{
             "type" => "session.status",
             "properties" => %{
               "sessionID" => "existing-session",
               "status" => %{"type" => "busy"}
             }
           }}
        )

        Process.sleep(50)

        send(
          runner_pid,
          {:opencode_event,
           %{
             "type" => "session.status",
             "properties" => %{
               "sessionID" => "existing-session",
               "status" => %{"type" => "idle"}
             }
           }}
        )
      end)

      {:ok, self()}
    end)
    |> expect(:send_prompt_async, fn _url, "existing-session", _parts, _opts -> :ok end)

    resume_opts =
      @default_opts ++
        [
          resume: true,
          container_id: "existing-container",
          session_id: "existing-session"
        ]

    {:ok, pid} = GenServer.start(TaskRunner, {task_id, resume_opts})
    ref = Process.monitor(pid)

    # Should receive merged todos: prior-run + current-run
    assert_receive {:todo_updated, ^task_id, merged_todos}, 5000

    # Prior-run items come first, unchanged
    assert Enum.at(merged_todos, 0)["id"] == "old-1"
    assert Enum.at(merged_todos, 0)["status"] == "completed"
    assert Enum.at(merged_todos, 1)["id"] == "old-2"
    assert Enum.at(merged_todos, 1)["status"] == "completed"

    # Current-run items follow with shifted positions
    assert Enum.at(merged_todos, 2)["id"] == "new-1"
    assert Enum.at(merged_todos, 2)["title"] == "Review"
    assert Enum.at(merged_todos, 3)["id"] == "new-2"
    assert Enum.at(merged_todos, 3)["title"] == "Test"

    assert length(merged_todos) == 4

    # Wait for completion to clean up
    assert_receive {:task_status_changed, ^task_id, "completed"}, 5000
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5_000
  end

  test "resume path dedupes prior-run todos that share IDs with current-run todos", %{
    task: task
  } do
    test_pid = self()
    task_id = task.id

    # Prior-run has todo-1 and todo-2
    prior_todos = %{
      "items" => [
        %{"id" => "shared-1", "title" => "Setup", "status" => "completed", "position" => 0},
        %{"id" => "old-only", "title" => "Teardown", "status" => "completed", "position" => 1}
      ]
    }

    task_with_todos = %{task | todo_items: prior_todos}

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task_with_todos end)
    |> stub(:update_task_status, fn _task, attrs ->
      send(test_pid, {:task_update, attrs})
      {:ok, task_with_todos}
    end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:restart, fn "existing-container" -> {:ok, %{port: 5000}} end)
    |> stub(:stop, fn _id -> :ok end)

    # New run reuses "shared-1" ID (updated status) and adds "new-only"
    new_run_todos = [
      %{"id" => "shared-1", "content" => "Setup v2", "status" => "in_progress"},
      %{"id" => "new-only", "content" => "Deploy", "status" => "pending"}
    ]

    Agents.Mocks.OpencodeClientMock
    |> expect(:health, fn _url -> :ok end)
    |> expect(:subscribe_events, fn _url, runner_pid ->
      spawn(fn ->
        Process.sleep(50)

        send(
          runner_pid,
          {:opencode_event,
           %{"type" => "todo.updated", "properties" => %{"todos" => new_run_todos}}}
        )

        Process.sleep(50)
        send(runner_pid, {:opencode_event, session_status("busy")})
        Process.sleep(50)
        send(runner_pid, {:opencode_event, session_status("idle")})
      end)

      {:ok, self()}
    end)
    |> expect(:send_prompt_async, fn _url, "existing-session", _parts, _opts -> :ok end)

    resume_opts =
      @default_opts ++
        [
          resume: true,
          container_id: "existing-container",
          session_id: "existing-session"
        ]

    {:ok, pid} = GenServer.start(TaskRunner, {task_id, resume_opts})
    ref = Process.monitor(pid)

    assert_receive {:todo_updated, ^task_id, merged_todos}, 5000

    # "old-only" is retained (not in current run)
    assert Enum.at(merged_todos, 0)["id"] == "old-only"
    assert Enum.at(merged_todos, 0)["status"] == "completed"

    # "shared-1" uses the current run's version (not duplicated)
    assert Enum.at(merged_todos, 1)["id"] == "shared-1"
    assert Enum.at(merged_todos, 1)["title"] == "Setup v2"
    assert Enum.at(merged_todos, 1)["status"] == "in_progress"

    # "new-only" is the new item
    assert Enum.at(merged_todos, 2)["id"] == "new-only"
    assert Enum.at(merged_todos, 2)["title"] == "Deploy"

    # No duplicates — exactly 3 items
    assert length(merged_todos) == 3

    assert_receive {:task_status_changed, ^task_id, "completed"}, 5000
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5_000
  end

  test "resume path fails when SSE subscription fails after health check", %{task: task} do
    test_pid = self()

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, attrs ->
      case attrs do
        %{status: "failed", error: error} -> send(test_pid, {:failed, error})
        _ -> :ok
      end

      {:ok, task}
    end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:restart, fn "existing-container" -> {:ok, %{port: 5000}} end)
    |> stub(:stop, fn _id -> :ok end)

    Agents.Mocks.OpencodeClientMock
    |> expect(:health, fn _url -> :ok end)
    |> expect(:subscribe_events, fn _url, _pid -> {:error, :connection_refused} end)

    resume_opts =
      @default_opts ++
        [
          resume: true,
          container_id: "existing-container",
          session_id: "existing-session"
        ]

    {:ok, pid} = GenServer.start(TaskRunner, {task.id, resume_opts})
    ref = Process.monitor(pid)

    assert_receive {:failed, error}, 5000
    assert String.contains?(error, "SSE subscription failed on resume")
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5_000
  end

  test "resume with prompt_instruction persists pending user message before reconnect", %{
    task: task
  } do
    test_pid = self()

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, attrs ->
      if is_binary(attrs[:output]) do
        send(test_pid, {:output_flushed, attrs.output})
      end

      {:ok, task}
    end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:restart, fn "existing-container" -> {:ok, %{port: 5000}} end)
    |> stub(:stop, fn _id -> :ok end)

    Agents.Mocks.OpencodeClientMock
    |> stub(:health, fn _url -> :ok end)
    |> stub(:subscribe_events, fn _url, _pid -> {:ok, self()} end)
    |> stub(:send_prompt_async, fn _url, "existing-session", _parts, _opts -> :ok end)

    resume_opts =
      @default_opts ++
        [
          resume: true,
          container_id: "existing-container",
          session_id: "existing-session",
          prompt_instruction: "Follow-up after reconnect"
        ]

    {:ok, pid} = GenServer.start(TaskRunner, {task.id, resume_opts})

    assert_receive {:output_flushed, output_json}, 5000
    assert {:ok, output_parts} = Jason.decode(output_json)

    assert Enum.any?(output_parts, fn part ->
             part["type"] == "user" and
               part["text"] == "Follow-up after reconnect" and
               part["pending"] == true
           end)

    # Wait for the full resume flow to complete (:restart_container ->
    # :wait_for_health_resume -> :send_prompt) so that all mock calls
    # finish while the test process is alive and Mox stubs are accessible.
    # Without this, the test process exits, NimbleOwnership switches from
    # shared mode to private mode, and any mock calls the GenServer makes
    # after that point raise Mox.UnexpectedCallError.
    assert_receive {:task_status_changed, _, "starting"}, 5000
    assert_receive {:task_status_changed, _, "running"}, 5000

    GenServer.stop(pid, :normal, 5_000)
  end

  defp session_status(status) do
    %{
      "type" => "session.status",
      "properties" => %{"sessionID" => "existing-session", "status" => %{"type" => status}}
    }
  end
end
