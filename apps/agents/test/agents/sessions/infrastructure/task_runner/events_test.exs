defmodule Agents.Sessions.Infrastructure.TaskRunner.EventsTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Sessions.Infrastructure.TaskRunner

  setup :set_mox_global
  setup :verify_on_exit!

  alias Agents.Test.AccountsFixtures
  alias Agents.SessionsFixtures

  setup do
    user = AccountsFixtures.user_fixture()
    task = SessionsFixtures.task_fixture(%{user_id: user.id})

    Phoenix.PubSub.subscribe(Jarga.PubSub, "task:#{task.id}")

    {:ok, task: task}
  end

  test "handles {:opencode_error, reason} by failing the task", %{task: task} do
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
    |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "abc123", port: 4096}} end)
    |> stub(:stop, fn _id -> :ok end)

    Agents.Mocks.OpencodeClientMock
    |> expect(:health, fn _url -> :ok end)
    |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-1"}} end)
    |> expect(:subscribe_events, fn _url, runner_pid ->
      # Simulate SSE error after a short delay
      spawn(fn ->
        Process.sleep(50)
        send(runner_pid, {:opencode_error, :connection_closed})
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
           pubsub: Jarga.PubSub
         ]}
      )

    assert_receive {:failed, error}, 5000
    assert String.contains?(error, "SSE connection failed")

    # Allow time for GenServer to stop
    Process.sleep(100)
    refute Process.alive?(pid)
  end

  test "broadcasts events via PubSub and detects completion via session.status idle", %{
    task: task
  } do
    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, _attrs -> {:ok, task} end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "abc123", port: 4096}} end)
    |> stub(:stop, fn _id -> :ok end)

    Agents.Mocks.OpencodeClientMock
    |> expect(:health, fn _url -> :ok end)
    |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-1"}} end)
    |> expect(:subscribe_events, fn _url, runner_pid ->
      # Simulate opencode SDK SSE events
      spawn(fn ->
        Process.sleep(50)

        # Session starts running (SDK sends "busy")
        send(runner_pid, {
          :opencode_event,
          %{
            "type" => "session.status",
            "properties" => %{"sessionID" => "sess-1", "status" => %{"type" => "busy"}}
          }
        })

        Process.sleep(50)

        # Text output streaming
        send(runner_pid, {
          :opencode_event,
          %{
            "type" => "message.part.updated",
            "properties" => %{"part" => %{"type" => "text", "text" => "Working on it..."}}
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
           pubsub: Jarga.PubSub
         ]}
      )

    assert_receive {:task_status_changed, _, "starting"}, 5000
    assert_receive {:task_status_changed, _, "running"}, 5000
    assert_receive {:task_event, _, %{"type" => "session.status"}}, 5000
    assert_receive {:task_event, _, %{"type" => "message.part.updated"}}, 5000
    assert_receive {:task_status_changed, _, "completed"}, 5000

    # Allow time for GenServer to stop
    Process.sleep(100)
    refute Process.alive?(pid)
  end

  test "handles session.error event by failing the task", %{task: task} do
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
    |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "abc123", port: 4096}} end)
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
           pubsub: Jarga.PubSub
         ]}
      )

    assert_receive {:failed, "Model rate limit exceeded"}, 5000

    Process.sleep(100)
    refute Process.alive?(pid)
  end

  test "auto-approves permission.asked events", %{task: task} do
    test_pid = self()

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, _attrs -> {:ok, task} end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "abc123", port: 4096}} end)
    |> stub(:stop, fn _id -> :ok end)

    Agents.Mocks.OpencodeClientMock
    |> expect(:health, fn _url -> :ok end)
    |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-1"}} end)
    |> expect(:subscribe_events, fn _url, runner_pid ->
      spawn(fn ->
        Process.sleep(50)

        # Permission request
        send(runner_pid, {
          :opencode_event,
          %{
            "type" => "permission.asked",
            "properties" => %{
              "id" => "perm-1",
              "sessionID" => "sess-1",
              "permission" => "bash"
            }
          }
        })

        Process.sleep(100)

        # Then complete
        send(runner_pid, {
          :opencode_event,
          %{
            "type" => "session.status",
            "properties" => %{"sessionID" => "sess-1", "status" => %{"type" => "busy"}}
          }
        })

        Process.sleep(50)

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
    |> expect(:reply_permission, fn _url, "sess-1", "perm-1", "always", _opts ->
      send(test_pid, :permission_replied)
      :ok
    end)

    {:ok, _pid} =
      GenServer.start(
        TaskRunner,
        {task.id,
         [
           container_provider: Agents.Mocks.ContainerProviderMock,
           opencode_client: Agents.Mocks.OpencodeClientMock,
           task_repo: Agents.Mocks.TaskRepositoryMock,
           pubsub: Jarga.PubSub
         ]}
      )

    assert_receive :permission_replied, 5000
    assert_receive {:task_status_changed, _, "completed"}, 5000
  end
end
