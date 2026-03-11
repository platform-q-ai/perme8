defmodule Agents.Sessions.Infrastructure.TaskRunner.TimeoutTest do
  use Agents.DataCase, async: false

  import Mox

  setup :set_mox_global
  setup :verify_on_exit!

  alias Agents.Test.AccountsFixtures
  alias Agents.SessionsFixtures

  setup do
    user = AccountsFixtures.user_fixture()
    task = SessionsFixtures.task_fixture(%{user_id: user.id})

    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")

    # Ensure fast health-check config so retries exhaust quickly
    original = Application.get_env(:agents, :sessions, [])
    merged = Keyword.merge(original, health_check_interval_ms: 10, health_check_max_retries: 3)
    Application.put_env(:agents, :sessions, merged)
    on_exit(fn -> Application.put_env(:agents, :sessions, original) end)

    {:ok, task: task}
  end

  @default_opts [
    container_provider: Agents.Mocks.ContainerProviderMock,
    opencode_client: Agents.Mocks.OpencodeClientMock,
    task_repo: Agents.Mocks.TaskRepositoryMock,
    pubsub: Perme8.Events.PubSub
  ]

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

    {:ok, pid} =
      GenServer.start(
        Agents.Sessions.Infrastructure.TaskRunner,
        {task.id, @default_opts}
      )

    ref = Process.monitor(pid)

    # Kill the process on test exit to prevent leaks into subsequent modules
    on_exit(fn -> if Process.alive?(pid), do: Process.exit(pid, :kill) end)

    assert_receive {:failed, "Health check timed out"}, 30_000

    # Verify PubSub broadcast
    assert_receive {:task_status_changed, _, "failed"}, 5000

    # Wait for GenServer to fully terminate before test cleanup
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5000
  end
end
