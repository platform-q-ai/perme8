defmodule Agents.Sessions.Infrastructure.TaskRunner.ContainerLifecycleTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Repo
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema
  alias Agents.Sessions.Infrastructure.TaskRunner

  alias Agents.SessionsFixtures
  alias Agents.Test.AccountsFixtures

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    user = AccountsFixtures.user_fixture()
    task = SessionsFixtures.task_fixture(%{user_id: user.id})

    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> Repo.get(TaskSchema, task.id) end)
    |> stub(:update_task_status, fn task, attrs ->
      task
      |> TaskSchema.status_changeset(attrs)
      |> Repo.update()
    end)

    {:ok,
     task: task,
     opts: [
       container_provider: Agents.Mocks.ContainerProviderMock,
       opencode_client: Agents.Mocks.OpencodeClientMock,
       task_repo: Agents.Mocks.TaskRepositoryMock,
       pubsub: Perme8.Events.PubSub
     ]}
  end

  defp assert_task_status(task_id, status) do
    task = Repo.get!(TaskSchema, task_id)
    assert task.status == status
    task
  end

  describe "container lifecycle" do
    test "calls stop (not remove) on task completion", %{task: task, opts: opts} do
      test_pid = self()

      Agents.Mocks.ContainerProviderMock
      |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "ctr-complete", port: 4096}} end)
      |> expect(:stop, fn "ctr-complete" ->
        send(test_pid, :container_stopped)
        :ok
      end)

      # Intentionally no remove expectation: any remove/1 call would violate
      # the lifecycle contract and fail this test via Mox.
      Agents.Mocks.OpencodeClientMock
      |> stub(:health, fn _url -> :ok end)
      |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-1"}} end)
      |> expect(:subscribe_events, fn _url, runner_pid ->
        spawn(fn ->
          Process.sleep(50)

          send(
            runner_pid,
            {:opencode_event,
             %{
               "type" => "session.status",
               "properties" => %{"sessionID" => "sess-1", "status" => %{"type" => "busy"}}
             }}
          )

          Process.sleep(50)

          send(
            runner_pid,
            {:opencode_event,
             %{
               "type" => "session.status",
               "properties" => %{"sessionID" => "sess-1", "status" => %{"type" => "idle"}}
             }}
          )
        end)

        {:ok, self()}
      end)
      |> expect(:send_prompt_async, fn _url, "sess-1", _parts, _opts -> :ok end)

      {:ok, pid} = GenServer.start(TaskRunner, {task.id, opts})
      ref = Process.monitor(pid)

      assert_receive {:task_status_changed, _, "completed"}, 5000
      assert_receive :container_stopped, 5000

      task = assert_task_status(task.id, "completed")
      assert task.completed_at != nil

      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5000
      refute Process.alive?(pid)
    end

    test "calls stop (not remove) on task failure", %{task: task, opts: opts} do
      test_pid = self()

      Agents.Mocks.ContainerProviderMock
      |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "ctr-fail", port: 4096}} end)
      |> expect(:stop, fn "ctr-fail" ->
        send(test_pid, :container_stopped)
        :ok
      end)

      Agents.Mocks.OpencodeClientMock
      |> stub(:health, fn _url -> :ok end)
      |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-1"}} end)
      |> expect(:subscribe_events, fn _url, runner_pid ->
        spawn(fn ->
          Process.sleep(50)
          send(runner_pid, {:opencode_error, :connection_closed})
        end)

        {:ok, self()}
      end)
      |> expect(:send_prompt_async, fn _url, "sess-1", _parts, _opts -> :ok end)

      {:ok, pid} = GenServer.start(TaskRunner, {task.id, opts})
      ref = Process.monitor(pid)

      assert_receive {:task_status_changed, _, "failed"}, 5000
      assert_receive :container_stopped, 5000

      task = assert_task_status(task.id, "failed")
      assert task.error =~ "SSE connection failed"

      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5000
      refute Process.alive?(pid)
    end

    test "calls stop (not remove) on task cancellation", %{task: task, opts: opts} do
      test_pid = self()

      Agents.Mocks.ContainerProviderMock
      |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "ctr-cancel", port: 4096}} end)
      |> expect(:stop, fn "ctr-cancel" ->
        send(test_pid, :container_stopped)
        :ok
      end)

      Agents.Mocks.OpencodeClientMock
      |> stub(:health, fn _url -> :ok end)
      |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-1"}} end)
      |> expect(:subscribe_events, fn _url, _runner_pid -> {:ok, self()} end)
      |> expect(:send_prompt_async, fn _url, "sess-1", _parts, _opts -> :ok end)
      |> expect(:abort_session, fn _url, "sess-1" -> {:ok, true} end)

      {:ok, pid} = GenServer.start(TaskRunner, {task.id, opts})
      ref = Process.monitor(pid)

      assert_receive {:task_status_changed, _, "running"}, 5000
      send(pid, :cancel)

      assert_receive {:task_status_changed, _, "cancelled"}, 5000
      assert_receive :container_stopped, 5000

      task = assert_task_status(task.id, "cancelled")
      assert task.completed_at != nil

      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5000
      refute Process.alive?(pid)
    end

    test "calls stop in terminate/2 as defensive cleanup", %{task: task, opts: opts} do
      test_pid = self()

      Agents.Mocks.ContainerProviderMock
      |> expect(:start, fn _image, _opts ->
        {:ok, %{container_id: "ctr-terminate", port: 4096}}
      end)
      |> expect(:stop, fn "ctr-terminate" ->
        send(test_pid, :container_stopped)
        :ok
      end)

      Agents.Mocks.OpencodeClientMock
      |> stub(:health, fn _url -> :ok end)
      |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-1"}} end)
      |> expect(:subscribe_events, fn _url, _runner_pid -> {:ok, self()} end)
      |> expect(:send_prompt_async, fn _url, "sess-1", _parts, _opts -> :ok end)

      {:ok, pid} = GenServer.start(TaskRunner, {task.id, opts})

      assert_receive {:task_status_changed, _, "running"}, 5000

      :ok = GenServer.stop(pid, :normal)
      assert_receive :container_stopped, 5000
      refute Process.alive?(pid)
    end

    test "does not call any container operations when container_id is nil", %{
      task: task,
      opts: opts
    } do
      Agents.Mocks.ContainerProviderMock
      |> expect(:start, fn _image, _opts -> {:error, :docker_unavailable} end)

      {:ok, pid} = GenServer.start(TaskRunner, {task.id, opts})
      ref = Process.monitor(pid)

      assert_receive {:task_status_changed, _, "failed"}, 5000

      task = assert_task_status(task.id, "failed")
      assert task.error =~ "Container start failed"

      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5000
      refute Process.alive?(pid)
    end
  end
end
