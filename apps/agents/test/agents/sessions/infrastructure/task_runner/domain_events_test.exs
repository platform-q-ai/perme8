defmodule Agents.Sessions.Infrastructure.TaskRunner.DomainEventsTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Sessions.Infrastructure.TaskRunner
  alias Agents.Sessions.Domain.Events.{TaskCompleted, TaskFailed, TaskCancelled}

  setup :set_mox_global
  setup :verify_on_exit!

  alias Agents.Test.AccountsFixtures
  alias Agents.SessionsFixtures

  setup do
    Perme8.Events.TestEventBus.start_global()
    user = AccountsFixtures.user_fixture()
    task = SessionsFixtures.task_fixture(%{user_id: user.id})
    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")
    {:ok, task: task, user: user}
  end

  test "emits TaskCompleted domain event when task completes", %{task: task, user: user} do
    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, _attrs -> {:ok, task} end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "abc", port: 4096}} end)
    |> stub(:stop, fn _id -> :ok end)

    Agents.Mocks.OpencodeClientMock
    |> expect(:health, fn _url -> :ok end)
    |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-1"}} end)
    |> expect(:subscribe_events, fn _url, runner_pid ->
      spawn(fn ->
        Process.sleep(50)

        # Session goes running
        send(runner_pid, {
          :opencode_event,
          %{
            "type" => "session.status",
            "properties" => %{"sessionID" => "sess-1", "status" => %{"type" => "busy"}}
          }
        })

        Process.sleep(50)

        # Session goes idle = completed
        send(runner_pid, {
          :opencode_event,
          %{
            "type" => "session.status",
            "properties" => %{"sessionID" => "sess-1", "status" => %{"type" => "idle"}}
          }
        })
      end)

      {:ok, self()}
    end)
    |> expect(:send_prompt_async, fn _url, "sess-1", _parts, _opts -> :ok end)

    {:ok, pid} =
      GenServer.start(
        TaskRunner,
        {task.id,
         [
           container_provider: Agents.Mocks.ContainerProviderMock,
           opencode_client: Agents.Mocks.OpencodeClientMock,
           task_repo: Agents.Mocks.TaskRepositoryMock,
           pubsub: Perme8.Events.PubSub,
           event_bus: Perme8.Events.TestEventBus
         ]}
      )

    # Allow the runner process to store events under our test process
    Perme8.Events.TestEventBus.allow(Perme8.Events.TestEventBus, self(), pid)

    assert_receive {:task_status_changed, _, "completed"}, 5000

    Process.sleep(100)

    events = Perme8.Events.TestEventBus.get_events()
    assert [%TaskCompleted{} = event] = events
    assert event.task_id == task.id
    assert event.user_id == user.id
    assert event.aggregate_id == task.id
    assert event.actor_id == user.id
  end

  test "emits TaskFailed domain event when task fails", %{task: task, user: user} do
    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, _attrs -> {:ok, task} end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "abc", port: 4096}} end)
    |> stub(:stop, fn _id -> :ok end)

    Agents.Mocks.OpencodeClientMock
    |> expect(:health, fn _url -> :ok end)
    |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-1"}} end)
    |> expect(:subscribe_events, fn _url, runner_pid ->
      spawn(fn ->
        Process.sleep(50)

        send(runner_pid, {
          :opencode_event,
          %{
            "type" => "session.error",
            "properties" => %{"error" => "Model rate limit exceeded"}
          }
        })
      end)

      {:ok, self()}
    end)
    |> expect(:send_prompt_async, fn _url, "sess-1", _parts, _opts -> :ok end)

    {:ok, pid} =
      GenServer.start(
        TaskRunner,
        {task.id,
         [
           container_provider: Agents.Mocks.ContainerProviderMock,
           opencode_client: Agents.Mocks.OpencodeClientMock,
           task_repo: Agents.Mocks.TaskRepositoryMock,
           pubsub: Perme8.Events.PubSub,
           event_bus: Perme8.Events.TestEventBus
         ]}
      )

    Perme8.Events.TestEventBus.allow(Perme8.Events.TestEventBus, self(), pid)

    assert_receive {:task_status_changed, _, "failed"}, 5000

    Process.sleep(100)

    events = Perme8.Events.TestEventBus.get_events()
    assert [%TaskFailed{} = event] = events
    assert event.task_id == task.id
    assert event.user_id == user.id
    assert event.error == "Model rate limit exceeded"
  end

  test "emits TaskCancelled domain event when task is cancelled", %{task: task, user: user} do
    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, _attrs -> {:ok, task} end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "abc", port: 4096}} end)
    |> stub(:stop, fn _id -> :ok end)

    Agents.Mocks.OpencodeClientMock
    |> expect(:health, fn _url -> :ok end)
    |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-1"}} end)
    |> expect(:subscribe_events, fn _url, _pid -> {:ok, self()} end)
    |> expect(:send_prompt_async, fn _url, "sess-1", _parts, _opts -> :ok end)
    |> expect(:abort_session, fn _url, "sess-1" -> {:ok, true} end)

    {:ok, pid} =
      GenServer.start(
        TaskRunner,
        {task.id,
         [
           container_provider: Agents.Mocks.ContainerProviderMock,
           opencode_client: Agents.Mocks.OpencodeClientMock,
           task_repo: Agents.Mocks.TaskRepositoryMock,
           pubsub: Perme8.Events.PubSub,
           event_bus: Perme8.Events.TestEventBus
         ]}
      )

    Perme8.Events.TestEventBus.allow(Perme8.Events.TestEventBus, self(), pid)

    # Wait for running state
    assert_receive {:task_status_changed, _, "running"}, 5000

    # Send cancel
    send(pid, :cancel)

    assert_receive {:task_status_changed, _, "cancelled"}, 5000

    Process.sleep(100)

    events = Perme8.Events.TestEventBus.get_events()
    assert [%TaskCancelled{} = event] = events
    assert event.task_id == task.id
    assert event.user_id == user.id
  end
end
