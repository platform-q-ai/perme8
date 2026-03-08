defmodule Agents.Sessions.Infrastructure.TaskRunner.EventsTest do
  use Agents.DataCase, async: false

  import ExUnit.CaptureLog
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
           pubsub: Perme8.Events.PubSub
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
    test_pid = self()

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, attrs ->
      case attrs do
        %{status: "starting"} -> send(test_pid, {:task_update_starting, attrs})
        %{status: "running"} -> send(test_pid, {:task_update_running, attrs})
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
           pubsub: Perme8.Events.PubSub
         ]}
      )

    assert_receive {:task_status_changed, _, "starting"}, 5000
    assert_receive {:task_update_starting, starting_attrs}, 5000
    assert starting_attrs.completed_at == nil
    assert_receive {:task_status_changed, _, "running"}, 5000
    assert_receive {:task_update_running, running_attrs}, 5000
    assert running_attrs.completed_at == nil
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
           pubsub: Perme8.Events.PubSub
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
           pubsub: Perme8.Events.PubSub
         ]}
      )

    assert_receive :permission_replied, 5000
    assert_receive {:task_status_changed, _, "completed"}, 5000
  end

  test "persists user follow-up parts with lower-camel messageId in cached output", %{task: task} do
    test_pid = self()

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, attrs ->
      if is_binary(attrs[:output]) do
        send(test_pid, {:output_flushed, attrs.output})
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
            "type" => "message.updated",
            "properties" => %{"info" => %{"role" => "user", "id" => "user-msg-1"}}
          }
        })

        send(runner_pid, {
          :opencode_event,
          %{
            "type" => "message.part.updated",
            "properties" => %{
              "part" => %{
                "id" => "user-part-1",
                "type" => "text",
                "text" => "Applied follow-up",
                "messageId" => "user-msg-1"
              }
            }
          }
        })

        send(runner_pid, {
          :opencode_event,
          %{
            "type" => "message.part.updated",
            "properties" => %{
              "part" => %{"id" => "asst-1", "type" => "text", "text" => "Assistant reply"}
            }
          }
        })

        send(runner_pid, {
          :opencode_event,
          %{
            "type" => "session.status",
            "properties" => %{"sessionID" => "sess-1", "status" => %{"type" => "busy"}}
          }
        })

        Process.sleep(20)

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

    assert_receive {:output_flushed, output_json}, 5000
    assert_receive {:task_status_changed, _, "completed"}, 5000

    assert {:ok, output_parts} = Jason.decode(output_json)

    assert Enum.any?(output_parts, fn part ->
             part["type"] == "user" and part["text"] == "Applied follow-up"
           end)
  end

  test "persists queued follow-up immediately so reload does not lose it", %{task: task} do
    test_pid = self()

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, attrs ->
      if is_binary(attrs[:output]) do
        send(test_pid, {:output_flushed, attrs.output})
      end

      {:ok, task}
    end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "abc123", port: 4096}} end)
    |> stub(:stop, fn _id -> :ok end)

    Agents.Mocks.OpencodeClientMock
    |> expect(:health, fn _url -> :ok end)
    |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-1"}} end)
    |> expect(:subscribe_events, fn _url, _runner_pid -> {:ok, self()} end)
    |> stub(:send_prompt_async, fn _url, _session_id, _parts, _opts -> :ok end)

    {:ok, pid} =
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

    assert_receive {:task_status_changed, _, "running"}, 5000

    assert :ok = GenServer.call(pid, {:send_message, "Queued follow-up"})

    assert_receive {:output_flushed, output_json}, 5000
    assert {:ok, output_parts} = Jason.decode(output_json)

    assert Enum.any?(output_parts, fn part ->
             part["type"] == "user" and part["text"] == "Queued follow-up" and
               part["pending"] == true
           end)
  end

  test "session.updated with valid summary persists session_summary", %{task: task} do
    test_pid = self()

    summary = %{"files" => 3, "additions" => 42, "deletions" => 7}

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, attrs ->
      case attrs do
        %{session_summary: ^summary} -> send(test_pid, {:session_summary_persisted, summary})
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
            "type" => "session.updated",
            "properties" => %{"info" => %{"summary" => summary}}
          }
        })
      end)

      {:ok, self()}
    end)
    |> expect(:send_prompt_async, fn _url, "sess-1", _parts, _opts -> :ok end)

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

    assert_receive {:session_summary_persisted, ^summary}, 5000
    assert_receive {:task_event, _, %{"type" => "session.updated"}}, 5000
  end

  test "session.updated with malformed summary does not persist", %{task: task} do
    test_pid = self()

    invalid_summary = %{"files" => "not_an_int", "extra_key" => true}

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, attrs ->
      if Map.has_key?(attrs, :session_summary) do
        send(test_pid, {:session_summary_persisted, attrs.session_summary})
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
            "type" => "session.updated",
            "properties" => %{"info" => %{"summary" => invalid_summary}}
          }
        })
      end)

      {:ok, self()}
    end)
    |> expect(:send_prompt_async, fn _url, "sess-1", _parts, _opts -> :ok end)

    log =
      capture_log(fn ->
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

        assert_receive {:task_event, _, %{"type" => "session.updated"}}, 5000
        refute_receive {:session_summary_persisted, _}, 200
      end)

    assert log =~ "invalid session summary"
    assert log =~ "not_an_int"
  end

  test "update_task_status logs error on failure", %{task: task} do
    test_pid = self()
    summary = %{"files" => 1, "additions" => 2, "deletions" => 3}

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, attrs ->
      if Map.has_key?(attrs, :session_summary) do
        send(test_pid, :session_summary_update_attempted)

        changeset =
          task
          |> Ecto.Changeset.change()
          |> Ecto.Changeset.add_error(:status, "is invalid")

        {:error, changeset}
      else
        {:ok, task}
      end
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
            "type" => "session.updated",
            "properties" => %{"info" => %{"summary" => summary}}
          }
        })
      end)

      {:ok, self()}
    end)
    |> expect(:send_prompt_async, fn _url, "sess-1", _parts, _opts -> :ok end)

    log =
      capture_log(fn ->
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

        assert_receive :session_summary_update_attempted, 5000
        assert_receive {:task_event, _, %{"type" => "session.updated"}}, 5000
      end)

    assert log =~ "failed to update task status"
    assert log =~ task.id
    assert log =~ "is invalid"
  end
end
