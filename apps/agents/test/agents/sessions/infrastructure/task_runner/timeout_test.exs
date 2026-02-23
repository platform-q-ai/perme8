defmodule Agents.Sessions.Infrastructure.TaskRunner.TimeoutTest do
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

    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")

    {:ok, task: task}
  end

  @default_opts [
    container_provider: Agents.Mocks.ContainerProviderMock,
    opencode_client: Agents.Mocks.OpencodeClientMock,
    task_repo: Agents.Mocks.TaskRepositoryMock,
    pubsub: Perme8.Events.PubSub
  ]

  test "task times out and fails with 'Task timed out'", %{task: task} do
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
    |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "abc", port: 4096}} end)
    |> stub(:stop, fn _id -> :ok end)

    Agents.Mocks.OpencodeClientMock
    |> expect(:health, fn _url -> :ok end)
    |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-1"}} end)
    |> expect(:subscribe_events, fn _url, _pid -> {:ok, self()} end)
    |> expect(:send_prompt_async, fn _url, "sess-1", _parts, _opts -> :ok end)

    {:ok, pid} =
      GenServer.start(
        TaskRunner,
        {task.id, @default_opts}
      )

    # Wait for running state
    assert_receive {:task_status_changed, _, "running"}, 5000

    # Simulate the timeout message directly (rather than waiting for the real timeout)
    send(pid, :timeout)

    assert_receive {:failed, "Task timed out"}, 5000

    Process.sleep(100)
    refute Process.alive?(pid)
  end

  test "health check exhaustion fails task when retries reach 0", %{task: task} do
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
    |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "abc", port: 4096}} end)
    |> stub(:stop, fn _id -> :ok end)

    # Health always fails — retries will be exhausted
    Agents.Mocks.OpencodeClientMock
    |> stub(:health, fn _url -> {:error, :unhealthy} end)

    {:ok, _pid} =
      GenServer.start(
        TaskRunner,
        {task.id, @default_opts}
      )

    assert_receive {:failed, "Health check timed out"}, 30_000

    # Verify PubSub broadcast
    assert_receive {:task_status_changed, _, "failed"}, 5000
  end
end
