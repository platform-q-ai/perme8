defmodule Agents.Sessions.Infrastructure.TaskRunner.ResumeTest do
  use Agents.DataCase, async: false

  import Mox

  alias Agents.Sessions.Infrastructure.TaskRunner

  setup :set_mox_global
  setup :verify_on_exit!

  alias Agents.Test.AccountsFixtures
  alias Agents.SessionsFixtures

  setup do
    user = AccountsFixtures.user_fixture()

    task =
      SessionsFixtures.task_fixture(%{
        user_id: user.id,
        container_id: "existing-container",
        session_id: "existing-session"
      })

    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")

    {:ok, task: task}
  end

  @default_opts [
    container_provider: Agents.Mocks.ContainerProviderMock,
    opencode_client: Agents.Mocks.OpencodeClientMock,
    task_repo: Agents.Mocks.TaskRepositoryMock,
    pubsub: Perme8.Events.PubSub
  ]

  test "resume path restarts container, skips session creation, and sends prompt", %{task: task} do
    test_pid = self()

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, attrs ->
      if attrs[:status] do
        send(test_pid, {:status_updated, attrs.status})
      end

      {:ok, task}
    end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:restart, fn "existing-container" ->
      {:ok, %{port: 5000}}
    end)
    |> stub(:stop, fn _id -> :ok end)

    Agents.Mocks.OpencodeClientMock
    |> expect(:health, fn _url -> :ok end)
    |> expect(:subscribe_events, fn _url, runner_pid ->
      # Simulate completion after prompt
      spawn(fn ->
        Process.sleep(100)

        send(runner_pid, {
          :opencode_event,
          %{
            "type" => "session.status",
            "properties" => %{"sessionID" => "existing-session", "status" => %{"type" => "busy"}}
          }
        })

        Process.sleep(50)

        send(runner_pid, {
          :opencode_event,
          %{
            "type" => "session.status",
            "properties" => %{"sessionID" => "existing-session", "status" => %{"type" => "idle"}}
          }
        })
      end)

      {:ok, self()}
    end)
    |> expect(:send_prompt_async, fn _url, "existing-session", _parts, _opts ->
      send(test_pid, :prompt_sent)
      :ok
    end)

    resume_opts =
      @default_opts ++
        [
          resume: true,
          container_id: "existing-container",
          session_id: "existing-session"
        ]

    {:ok, _pid} = GenServer.start(TaskRunner, {task.id, resume_opts})

    assert_receive :prompt_sent, 5000
    assert_receive {:task_status_changed, _, "starting"}, 5000
    assert_receive {:task_status_changed, _, "running"}, 5000
    assert_receive {:task_status_changed, _, "completed"}, 5000
  end

  test "resume path fails when container restart fails", %{task: task} do
    test_pid = self()

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, %{status: "failed", error: error} ->
      send(test_pid, {:failed, error})
      {:ok, task}
    end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:restart, fn "existing-container" ->
      {:error, :container_not_found}
    end)
    |> stub(:stop, fn _id -> :ok end)

    resume_opts =
      @default_opts ++
        [
          resume: true,
          container_id: "existing-container",
          session_id: "existing-session"
        ]

    {:ok, _pid} = GenServer.start(TaskRunner, {task.id, resume_opts})

    assert_receive {:failed, error}, 5000
    assert String.contains?(error, "Container restart failed")
  end

  test "resume path fails when SSE subscription fails after health check", %{task: task} do
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
    |> expect(:restart, fn "existing-container" -> {:ok, %{port: 5000}} end)
    |> stub(:stop, fn _id -> :ok end)

    Agents.Mocks.OpencodeClientMock
    |> expect(:health, fn _url -> :ok end)
    |> expect(:subscribe_events, fn _url, _pid -> {:error, :connection_refused} end)

    resume_opts =
      @default_opts ++
        [
          resume: true,
          container_id: "existing-container",
          session_id: "existing-session"
        ]

    {:ok, _pid} = GenServer.start(TaskRunner, {task.id, resume_opts})

    assert_receive {:failed, error}, 5000
    assert String.contains?(error, "SSE subscription failed on resume")
  end
end
