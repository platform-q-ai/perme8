defmodule Agents.Sessions.Infrastructure.TaskRunner.InitTest do
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
    {:ok, task: task, user: user}
  end

  test "init loads task from DB", %{task: task} do
    test_pid = self()

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn id ->
      send(test_pid, {:get_task_called, id})
      task
    end)
    |> stub(:update_task_status, fn _task, _attrs -> {:ok, task} end)

    Agents.Mocks.ContainerProviderMock
    |> stub(:start, fn _image, _opts -> {:error, :test_stop} end)

    # Use start instead of start_link to avoid being linked to the test process
    {:ok, _pid} =
      GenServer.start(
        TaskRunner,
        {task.id,
         [
           container_provider: Agents.Mocks.ContainerProviderMock,
           opencode_client: Agents.Mocks.OpencodeClientMock,
           task_repo: Agents.Mocks.TaskRepositoryMock,
           pubsub: Perme8.Events.PubSub
         ]}
      )

    assert_receive {:get_task_called, id}, 5000
    assert id == task.id
  end

  test "on container start success, updates status to starting", %{task: task} do
    test_pid = self()

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, %{status: status} = _attrs ->
      send(test_pid, {:status_updated, status})
      {:ok, task}
    end)

    Agents.Mocks.ContainerProviderMock
    |> stub(:start, fn _image, _opts -> {:ok, %{container_id: "abc123", port: 4096}} end)
    |> stub(:stop, fn _id -> :ok end)

    Agents.Mocks.OpencodeClientMock
    |> stub(:health, fn _url -> {:error, :unhealthy} end)

    {:ok, _pid} =
      GenServer.start(
        TaskRunner,
        {task.id,
         [
           container_provider: Agents.Mocks.ContainerProviderMock,
           opencode_client: Agents.Mocks.OpencodeClientMock,
           task_repo: Agents.Mocks.TaskRepositoryMock,
           pubsub: Perme8.Events.PubSub
         ]}
      )

    assert_receive {:status_updated, "starting"}, 5000
  end

  test "init returns {:stop, :task_not_found} when task is nil", %{task: task} do
    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> nil end)

    result =
      GenServer.start(
        TaskRunner,
        {task.id,
         [
           container_provider: Agents.Mocks.ContainerProviderMock,
           opencode_client: Agents.Mocks.OpencodeClientMock,
           task_repo: Agents.Mocks.TaskRepositoryMock,
           pubsub: Perme8.Events.PubSub
         ]}
      )

    assert {:error, :task_not_found} = result
  end

  test "on container start failure, updates status to failed", %{task: task} do
    test_pid = self()

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, %{status: "failed", error: error} ->
      send(test_pid, {:failed, error})
      {:ok, task}
    end)

    Agents.Mocks.ContainerProviderMock
    |> stub(:start, fn _image, _opts -> {:error, :image_not_found} end)

    {:ok, _pid} =
      GenServer.start(
        TaskRunner,
        {task.id,
         [
           container_provider: Agents.Mocks.ContainerProviderMock,
           opencode_client: Agents.Mocks.OpencodeClientMock,
           task_repo: Agents.Mocks.TaskRepositoryMock,
           pubsub: Perme8.Events.PubSub
         ]}
      )

    assert_receive {:failed, error}, 5000
    assert String.contains?(error, "Container start failed")
  end

  test "prewarmed fresh container runs preparation and auth refresh before first prompt", %{
    task: task
  } do
    test_pid = self()

    {:module, auth_refresher_mod, _, _} =
      defmodule :"Agents.Sessions.TaskRunnerInitTest.AuthRefresherMock.#{System.unique_integer([:positive])}" do
        def set_test_pid(pid), do: :persistent_term.put({__MODULE__, :test_pid}, pid)

        def refresh_auth(base_url, _opencode_client) do
          send(:persistent_term.get({__MODULE__, :test_pid}), {:auth_refreshed, base_url})
          {:ok, ["openai"]}
        end
      end

    auth_refresher_mod.set_test_pid(test_pid)

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, attrs ->
      if attrs[:status] do
        send(test_pid, {:status_updated, attrs.status})
      end

      {:ok, task}
    end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:restart, fn "warmed-container" -> {:ok, %{port: 4096}} end)
    |> expect(:prepare_fresh_start, fn "warmed-container" ->
      send(test_pid, :fresh_start_prepared)
      :ok
    end)
    |> stub(:stop, fn _id -> :ok end)

    Agents.Mocks.OpencodeClientMock
    |> stub(:health, fn _url -> :ok end)
    |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "fresh-session"}} end)
    |> expect(:subscribe_events, fn _url, runner_pid ->
      spawn(fn ->
        Process.sleep(50)

        send(
          runner_pid,
          {:opencode_event,
           %{"type" => "session.status", "properties" => %{"status" => %{"type" => "busy"}}}}
        )

        Process.sleep(50)

        send(
          runner_pid,
          {:opencode_event,
           %{"type" => "session.status", "properties" => %{"status" => %{"type" => "idle"}}}}
        )
      end)

      {:ok, self()}
    end)
    |> expect(:send_prompt_async, fn _url, "fresh-session", _parts, _opts ->
      send(test_pid, :prompt_sent)
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
           auth_refresher: auth_refresher_mod,
           prewarmed_container_id: "warmed-container",
           fresh_warm_container: true,
           pubsub: Perme8.Events.PubSub
         ]}
      )

    assert_receive {:status_updated, "starting"}, 5000
    assert_receive :fresh_start_prepared, 5000
    assert_receive {:auth_refreshed, "http://localhost:4096"}, 5000
    assert_receive :prompt_sent, 5000
  end
end
