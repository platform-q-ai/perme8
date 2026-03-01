defmodule Agents.Sessions.Infrastructure.TaskRunner.TodoTest do
  use Agents.DataCase, async: false

  import ExUnit.CaptureLog
  import Mox

  alias Agents.Sessions.Infrastructure.TaskRunner
  alias Agents.Test.AccountsFixtures
  alias Agents.SessionsFixtures

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    user = AccountsFixtures.user_fixture()
    task = SessionsFixtures.task_fixture(%{user_id: user.id})

    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")

    {:ok, task: task}
  end

  @default_opts [
    container_provider: Agents.Mocks.ContainerProviderMock,
    opencode_client: Agents.Mocks.OpencodeClientMock,
    task_repo: Agents.Mocks.TaskRepositoryMock,
    pubsub: Perme8.Events.PubSub
  ]

  describe "todo.updated handling" do
    test "initializes todo state and flush tracking fields", %{task: task} do
      test_pid = self()

      start_runner(task, test_pid, [todo_event([])], complete?: false)

      {:ok, pid} = GenServer.start(TaskRunner, {task.id, @default_opts})

      assert_receive {:task_status_changed, _, "running"}, 5000

      state = :sys.get_state(pid)

      assert state.todo_items == []
      assert state.todo_version == 0
      assert state.last_flushed_todo_version == 0

      stop_runner(pid)
    end

    test "parses todo.updated and broadcasts parsed todo items", %{task: task} do
      test_pid = self()
      task_id = task.id

      raw_todos = [
        %{"id" => "todo-1", "content" => "Plan", "status" => "completed"},
        %{"id" => "todo-2", "content" => "Code", "status" => "in_progress"}
      ]

      start_runner(task, test_pid, [todo_event(raw_todos)], complete?: false)

      {:ok, pid} = GenServer.start(TaskRunner, {task.id, @default_opts})

      assert_receive {:todo_updated, ^task_id, todo_items}, 5000

      assert todo_items == [
               %{"id" => "todo-1", "title" => "Plan", "status" => "completed", "position" => 0},
               %{"id" => "todo-2", "title" => "Code", "status" => "in_progress", "position" => 1}
             ]

      assert_receive {:task_event, ^task_id, %{"type" => "todo.updated"}}, 5000

      state = :sys.get_state(pid)
      assert state.todo_items == todo_items

      stop_runner(pid)
    end

    test "replaces cached todo list when a second todo.updated arrives", %{task: task} do
      test_pid = self()
      task_id = task.id

      first = [%{"id" => "todo-1", "content" => "Plan", "status" => "pending"}]

      second = [
        %{"id" => "todo-3", "content" => "Rewrite", "status" => "in_progress"},
        %{"id" => "todo-4", "content" => "Ship", "status" => "pending"}
      ]

      start_runner(task, test_pid, [todo_event(first), todo_event(second)], complete?: false)

      {:ok, pid} = GenServer.start(TaskRunner, {task.id, @default_opts})

      assert_receive {:todo_updated, ^task_id, _}, 5000
      assert_receive {:todo_updated, ^task_id, last_items}, 5000

      assert last_items == [
               %{
                 "id" => "todo-3",
                 "title" => "Rewrite",
                 "status" => "in_progress",
                 "position" => 0
               },
               %{"id" => "todo-4", "title" => "Ship", "status" => "pending", "position" => 1}
             ]

      assert :sys.get_state(pid).todo_items == last_items

      stop_runner(pid)
    end

    test "logs warning and ignores malformed todo.updated event", %{task: task} do
      test_pid = self()

      start_runner(task, test_pid, [%{"type" => "todo.updated", "properties" => %{"oops" => []}}],
        complete?: false
      )

      log =
        capture_log(fn ->
          {:ok, pid} = GenServer.start(TaskRunner, {task.id, @default_opts})

          assert_receive {:task_status_changed, _, "running"}, 5000
          assert Process.alive?(pid)

          refute_receive {:todo_updated, _, _}, 500
          stop_runner(pid)
        end)

      assert log =~ "malformed todo.updated event"
    end
  end

  describe "todo_items persistence" do
    test "flush_output includes todo_items when present", %{task: task} do
      test_pid = self()
      task_id = task.id

      start_runner(
        task,
        test_pid,
        [todo_event([%{"id" => "todo-1", "content" => "Plan", "status" => "pending"}])],
        complete?: false
      )

      {:ok, pid} = GenServer.start(TaskRunner, {task.id, @default_opts})

      assert_receive {:todo_updated, ^task_id, _}, 5000

      send(pid, :flush_output)

      assert_receive {:task_update, %{todo_items: %{"items" => [%{"id" => "todo-1"}]}}}, 5000

      stop_runner(pid)
    end

    test "flush_output avoids redundant todo writes when unchanged", %{task: task} do
      test_pid = self()
      task_id = task.id

      start_runner(
        task,
        test_pid,
        [todo_event([%{"id" => "todo-1", "content" => "Plan", "status" => "pending"}])],
        complete?: false
      )

      {:ok, pid} = GenServer.start(TaskRunner, {task.id, @default_opts})

      assert_receive {:todo_updated, ^task_id, _}, 5000

      send(pid, :flush_output)
      assert_receive {:task_update, %{todo_items: %{"items" => [_]}}}, 5000

      send(pid, :flush_output)
      refute_receive {:task_update, %{todo_items: _}}, 500

      stop_runner(pid)
    end

    test "includes todo_items in completed task write", %{task: task} do
      test_pid = self()

      events = [
        todo_event([%{"id" => "todo-1", "content" => "Plan", "status" => "completed"}]),
        session_status("busy"),
        session_status("idle")
      ]

      start_runner(task, test_pid, events)

      {:ok, _pid} = GenServer.start(TaskRunner, {task.id, @default_opts})

      assert_receive {:task_update,
                      %{status: "completed", todo_items: %{"items" => [%{"id" => "todo-1"}]}}},
                     5000
    end

    test "includes todo_items in failed task write", %{task: task} do
      test_pid = self()

      events = [
        todo_event([%{"id" => "todo-1", "content" => "Plan", "status" => "pending"}]),
        %{"type" => "session.error", "properties" => %{"error" => "boom"}}
      ]

      start_runner(task, test_pid, events)

      {:ok, _pid} = GenServer.start(TaskRunner, {task.id, @default_opts})

      assert_receive {:task_update,
                      %{status: "failed", todo_items: %{"items" => [%{"id" => "todo-1"}]}}},
                     5000
    end
  end

  defp start_runner(task, test_pid, events, opts \\ []) do
    complete? = Keyword.get(opts, :complete?, true)

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, attrs ->
      send(test_pid, {:task_update, attrs})
      {:ok, task}
    end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "abc123", port: 4096}} end)
    |> stub(:stop, fn _id -> :ok end)

    Agents.Mocks.OpencodeClientMock
    |> expect(:health, fn _url -> :ok end)
    |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-1"}} end)
    |> expect(:subscribe_events, fn _url, runner_pid ->
      spawn(fn -> send_events(runner_pid, events, complete?) end)
      {:ok, self()}
    end)
    |> expect(:send_prompt_async, fn _url, "sess-1", _parts, _opts -> :ok end)
    |> stub(:abort_session, fn _url, _session_id -> {:ok, true} end)
  end

  defp send_events(runner_pid, events, complete?) do
    Enum.each(events, fn event ->
      Process.sleep(30)
      send(runner_pid, {:opencode_event, event})
    end)

    if complete? and events == [] do
      send(runner_pid, {:opencode_event, session_status("busy")})
      send(runner_pid, {:opencode_event, session_status("idle")})
    end
  end

  defp todo_event(todos) do
    %{"type" => "todo.updated", "properties" => %{"todos" => todos}}
  end

  defp session_status(status) do
    %{
      "type" => "session.status",
      "properties" => %{"sessionID" => "sess-1", "status" => %{"type" => status}}
    }
  end

  defp stop_runner(pid) do
    ref = Process.monitor(pid)
    send(pid, :cancel)
    assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5000
  end
end
