defmodule Agents.Sessions.Infrastructure.TaskRunner.SessionTrackingTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Mocks.{ContainerProviderMock, OpencodeClientMock, TaskRepositoryMock}

  alias Agents.Sessions.Domain.Events.{SessionErrorOccurred, SessionStateChanged}

  alias Agents.Sessions.Infrastructure.TaskRunner
  alias Agents.SessionsFixtures
  alias Agents.Test.AccountsFixtures
  alias Perme8.Events.TestEventBus

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    TestEventBus.start_global()
    user = AccountsFixtures.user_fixture()
    task = SessionsFixtures.task_fixture(%{user_id: user.id})

    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")

    {:ok, task: task, user: user}
  end

  test "initializes a session on init and processes sdk events", %{task: task} do
    pid = start_task_runner(task)
    TestEventBus.allow(TestEventBus, self(), pid)

    send(pid, {:opencode_event, %{"type" => "server.connected", "properties" => %{}}})

    assert_receive {:task_event, _, %{"type" => "server.connected"}}, 5000
    Process.sleep(100)

    assert [%Agents.Sessions.Domain.Events.SessionServerConnected{} = event] =
             TestEventBus.get_events()

    assert event.task_id == task.id
  end

  test "session.error terminal event emits SessionErrorOccurred and SessionStateChanged", %{
    task: task
  } do
    pid = start_task_runner(task)
    TestEventBus.allow(TestEventBus, self(), pid)

    :sys.replace_state(pid, fn state ->
      %{state | session: %{state.session | lifecycle_state: :running}}
    end)

    send(pid, {
      :opencode_event,
      %{"type" => "session.status", "properties" => %{"status" => %{"type" => "busy"}}}
    })

    send(pid, {
      :opencode_event,
      %{
        "type" => "session.error",
        "properties" => %{
          "category" => "auth",
          "message" => "authentication failed",
          "error" => "authentication failed"
        }
      }
    })

    assert_receive {:task_status_changed, _, "failed"}, 5000

    Process.sleep(150)

    events = TestEventBus.get_events()
    assert Enum.any?(events, &match?(%SessionErrorOccurred{}, &1))
    assert Enum.any?(events, &match?(%SessionStateChanged{to_state: :failed}, &1))
  end

  test "ignored sdk events do not emit domain events", %{task: task} do
    pid = start_task_runner(task)
    TestEventBus.allow(TestEventBus, self(), pid)

    send(pid, {:opencode_event, %{"type" => "pty.created", "properties" => %{}}})

    assert_receive {:task_event, _, %{"type" => "pty.created"}}, 5000
    Process.sleep(100)
    assert [] == TestEventBus.get_events()
    assert Process.alive?(pid)
  end

  test "sdk event handler exception does not crash task runner", %{task: task} do
    pid = start_task_runner(task, event_bus: __MODULE__.RaisingEventBus)

    send(
      pid,
      {:opencode_event, %{"type" => "message.updated", "properties" => %{"id" => "msg-2"}}}
    )

    assert_receive {:task_event, _, %{"type" => "message.updated"}}, 5000
    assert Process.alive?(pid)
  end

  test "malformed sdk events are handled gracefully", %{task: task} do
    pid = start_task_runner(task)
    TestEventBus.allow(TestEventBus, self(), pid)

    send(pid, {:opencode_event, :not_a_map})

    assert_receive {:task_event, _, :not_a_map}, 5000
    assert [] == TestEventBus.get_events()
    assert Process.alive?(pid)
  end

  defmodule RaisingEventBus do
    def emit_all(_events), do: raise("boom")
    def emit(_event), do: :ok
  end

  defp start_task_runner(task, extra_opts \\ []) do
    TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, _attrs -> {:ok, task} end)

    ContainerProviderMock
    |> stub(:start, fn _image, _opts -> {:ok, %{container_id: "container-1", port: 4096}} end)
    |> stub(:stop, fn _id -> :ok end)
    |> stub(:stats, fn _id -> {:error, :unsupported} end)

    OpencodeClientMock
    |> stub(:health, fn _url -> :ok end)
    |> stub(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-1"}} end)
    |> stub(:subscribe_events, fn _url, _runner_pid -> {:ok, self()} end)
    |> stub(:send_prompt_async, fn _url, "sess-1", _parts, _opts -> :ok end)

    opts = [
      container_provider: ContainerProviderMock,
      opencode_client: OpencodeClientMock,
      task_repo: TaskRepositoryMock,
      pubsub: Perme8.Events.PubSub,
      event_bus: TestEventBus
    ]

    {:ok, pid} = GenServer.start(TaskRunner, {task.id, Keyword.merge(opts, extra_opts)})

    assert_receive {:task_status_changed, _, "running"}, 5000

    ExUnit.Callbacks.on_exit(fn ->
      if Process.alive?(pid), do: Process.exit(pid, :kill)
    end)

    pid
  end
end
