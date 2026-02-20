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
           pubsub: Jarga.PubSub
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
           pubsub: Jarga.PubSub
         ]}
      )

    assert_receive {:status_updated, "starting"}, 5000
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
           pubsub: Jarga.PubSub
         ]}
      )

    assert_receive {:failed, error}, 5000
    assert String.contains?(error, "Container start failed")
  end
end
