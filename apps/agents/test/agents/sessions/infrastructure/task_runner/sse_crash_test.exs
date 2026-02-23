defmodule Agents.Sessions.Infrastructure.TaskRunner.SseCrashTest do
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

  test "SSE process crash with non-normal reason fails the task", %{task: task} do
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
      # Spawn a monitored process that crashes with a non-normal reason
      sse_pid =
        spawn(fn ->
          Process.sleep(100)
          exit(:connection_reset)
        end)

      # The TaskRunner monitors the SSE process via Process.monitor
      # We need to simulate the DOWN message
      spawn(fn ->
        ref = Process.monitor(sse_pid)

        receive do
          {:DOWN, ^ref, :process, ^sse_pid, reason} ->
            send(runner_pid, {:DOWN, make_ref(), :process, sse_pid, reason})
        end
      end)

      {:ok, sse_pid}
    end)
    |> expect(:send_prompt_async, fn _url, "sess-1", _parts, _opts -> :ok end)

    {:ok, pid} =
      GenServer.start(
        TaskRunner,
        {task.id, @default_opts}
      )

    assert_receive {:failed, error}, 5000
    assert String.contains?(error, "SSE process crashed")

    Process.sleep(100)
    refute Process.alive?(pid)
  end

  test "SSE process exit with :normal reason does NOT fail the task", %{task: task} do
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
      # Send a normal DOWN after a short delay
      spawn(fn ->
        Process.sleep(100)
        send(runner_pid, {:DOWN, make_ref(), :process, self(), :normal})
      end)

      {:ok, self()}
    end)
    |> expect(:send_prompt_async, fn _url, "sess-1", _parts, _opts -> :ok end)

    {:ok, pid} =
      GenServer.start(
        TaskRunner,
        {task.id, @default_opts}
      )

    assert_receive {:task_status_changed, _, "running"}, 5000

    # Give time for the :normal DOWN to be processed
    Process.sleep(200)

    # The process should still be alive since :normal exits are ignored
    assert Process.alive?(pid)

    # Clean up by sending cancel
    send(pid, :cancel)
    Process.sleep(100)
  end
end
