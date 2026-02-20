defmodule Agents.Sessions.Infrastructure.TaskRunner.CompletionTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Sessions.Infrastructure.TaskRunner

  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    user = Agents.Test.AccountsFixtures.user_fixture()
    task = Agents.SessionsFixtures.task_fixture(%{user_id: user.id})
    Phoenix.PubSub.subscribe(Jarga.PubSub, "task:#{task.id}")
    {:ok, task: task}
  end

  test "cancel message aborts session and stops container", %{task: task} do
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
           pubsub: Jarga.PubSub
         ]}
      )

    # Wait for running state
    assert_receive {:task_status_changed, _, "running"}, 5000

    # Send cancel
    send(pid, :cancel)

    assert_receive {:task_status_changed, _, "cancelled"}, 5000

    # Allow time for GenServer to stop
    Process.sleep(100)
    refute Process.alive?(pid)
  end
end
