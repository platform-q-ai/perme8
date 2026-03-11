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

    ref = Process.monitor(pid)

    assert_receive {:failed, error}, 5000
    assert String.contains?(error, "SSE process crashed")

    # Wait for GenServer to fully terminate before test cleanup
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5000
    refute Process.alive?(pid)
  end

  test "SSE process exit with :normal reason does NOT fail the task", %{task: task} do
    test_pid = self()

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, attrs ->
      if attrs[:status] == "failed" do
        send(test_pid, {:failed, attrs.error})
      end

      if attrs[:status] == "completed" do
        send(test_pid, {:completed_update, attrs})
      end

      {:ok, task}
    end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "abc123", port: 4096}} end)
    |> stub(:stop, fn _id -> :ok end)

    reconnect_calls = :atomics.new(1, [])

    Agents.Mocks.OpencodeClientMock
    |> expect(:health, fn _url -> :ok end)
    |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-1"}} end)
    |> expect(:subscribe_events, 2, fn _url, runner_pid ->
      attempt = :atomics.add_get(reconnect_calls, 1, 1)

      case attempt do
        1 ->
          sse_pid = spawn(fn -> Process.sleep(:infinity) end)

          spawn(fn ->
            Process.sleep(20)

            send(runner_pid, {
              :opencode_event,
              %{
                "type" => "session.status",
                "properties" => %{"sessionID" => "sess-1", "status" => %{"type" => "busy"}}
              }
            })

            send(runner_pid, {
              :opencode_event,
              %{
                "type" => "message.part.updated",
                "properties" => %{
                  "part" => %{"id" => "txt-1", "type" => "text", "text" => "before reconnect"}
                }
              }
            })

            Process.sleep(20)
            send(runner_pid, {:DOWN, make_ref(), :process, sse_pid, :normal})
          end)

          {:ok, sse_pid}

        2 ->
          sse_pid = spawn(fn -> Process.sleep(:infinity) end)

          spawn(fn ->
            Process.sleep(20)

            send(runner_pid, {
              :opencode_event,
              %{
                "type" => "todo.updated",
                "properties" => %{
                  "todos" => [
                    %{"id" => "todo-2", "content" => "Resume stream", "status" => "completed"}
                  ]
                }
              }
            })

            send(runner_pid, {
              :opencode_event,
              %{
                "type" => "message.part.updated",
                "properties" => %{
                  "part" => %{"id" => "txt-2", "type" => "text", "text" => "after reconnect"}
                }
              }
            })

            send(runner_pid, {
              :opencode_event,
              %{
                "type" => "session.status",
                "properties" => %{"sessionID" => "sess-1", "status" => %{"type" => "idle"}}
              }
            })
          end)

          {:ok, sse_pid}
      end
    end)
    |> expect(:send_prompt_async, fn _url, "sess-1", _parts, _opts -> :ok end)

    {:ok, pid} =
      GenServer.start(
        TaskRunner,
        {task.id, @default_opts}
      )

    ref = Process.monitor(pid)

    assert_receive {:task_status_changed, _, "running"}, 5000
    assert_receive {:task_status_changed, _, "completed"}, 5000

    assert_receive {:completed_update, attrs}, 5000
    assert is_binary(attrs.output)
    assert %{"items" => [todo]} = attrs.todo_items
    assert todo["id"] == "todo-2"

    assert {:ok, parts} = Jason.decode(attrs.output)

    assert Enum.any?(parts, fn part ->
             part["type"] == "text" and part["text"] == "after reconnect"
           end)

    refute_receive {:failed, _}, 200
    assert :atomics.get(reconnect_calls, 1) == 2

    # Wait for GenServer to fully terminate before test cleanup
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5000
  end

  test "normal SSE DOWN while active does not fail immediately", %{task: task} do
    test_pid = self()

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, attrs ->
      if attrs[:status] == "failed" do
        send(test_pid, {:failed, attrs.error})
      end

      {:ok, task}
    end)

    Agents.Mocks.ContainerProviderMock
    |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "abc123", port: 4096}} end)
    |> stub(:stop, fn _id -> :ok end)

    reconnect_calls = :atomics.new(1, [])

    Agents.Mocks.OpencodeClientMock
    |> expect(:health, fn _url -> :ok end)
    |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-1"}} end)
    |> expect(:subscribe_events, 2, fn _url, runner_pid ->
      attempt = :atomics.add_get(reconnect_calls, 1, 1)
      sse_pid = spawn(fn -> Process.sleep(:infinity) end)

      if attempt == 1 do
        spawn(fn ->
          Process.sleep(30)

          send(runner_pid, {
            :opencode_event,
            %{
              "type" => "session.status",
              "properties" => %{"sessionID" => "sess-1", "status" => %{"type" => "busy"}}
            }
          })

          send(runner_pid, {:DOWN, make_ref(), :process, sse_pid, :normal})
        end)
      end

      {:ok, sse_pid}
    end)
    |> expect(:send_prompt_async, fn _url, "sess-1", _parts, _opts -> :ok end)
    |> stub(:abort_session, fn _url, _session_id -> {:ok, true} end)

    {:ok, pid} = GenServer.start(TaskRunner, {task.id, @default_opts})
    ref = Process.monitor(pid)

    assert_receive {:task_status_changed, _, "running"}, 5000
    refute_receive {:failed, _}, 200
    assert :atomics.get(reconnect_calls, 1) == 2

    assert Process.alive?(pid)

    send(pid, :cancel)

    # Wait for GenServer to fully terminate before test cleanup
    assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5000
  end
end
