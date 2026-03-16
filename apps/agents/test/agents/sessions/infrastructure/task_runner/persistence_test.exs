defmodule Agents.Sessions.Infrastructure.TaskRunner.PersistenceTest do
  @moduledoc """
  Tests for session_id persistence, output caching, and PubSub broadcast
  when session_id is set. Covers acceptance criteria 3-5 of #196.
  """
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

    # Use real DB operations so we can assert persisted state
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

  describe "session_id persistence (AC 4)" do
    test "persists session_id to DB after create_session succeeds", %{task: task, opts: opts} do
      Agents.Mocks.ContainerProviderMock
      |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "ctr-1", port: 4096}} end)
      |> stub(:stop, fn _id -> :ok end)

      Agents.Mocks.OpencodeClientMock
      |> expect(:health, fn _url -> :ok end)
      |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-persist"}} end)
      |> expect(:subscribe_events, fn _url, runner_pid ->
        spawn(fn ->
          Process.sleep(50)

          send(runner_pid, {
            :opencode_event,
            %{
              "type" => "session.status",
              "properties" => %{"sessionID" => "sess-persist", "status" => %{"type" => "busy"}}
            }
          })

          Process.sleep(50)

          send(runner_pid, {
            :opencode_event,
            %{
              "type" => "session.status",
              "properties" => %{"sessionID" => "sess-persist", "status" => %{"type" => "idle"}}
            }
          })
        end)

        {:ok, self()}
      end)
      |> expect(:send_prompt_async, fn _url, "sess-persist", _parts, _opts -> :ok end)

      {:ok, pid} = GenServer.start(TaskRunner, {task.id, opts})
      ref = Process.monitor(pid)

      assert_receive {:task_status_changed, _, "completed"}, 5000
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5_000

      # Assert session_id was persisted to the DB
      updated_task = Repo.get!(TaskSchema, task.id)
      assert updated_task.session_id == "sess-persist"
    end
  end

  describe "session_id PubSub broadcast (AC 3)" do
    test "broadcasts session_id_set event via PubSub after session creation", %{
      task: task,
      opts: opts
    } do
      Agents.Mocks.ContainerProviderMock
      |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "ctr-2", port: 4096}} end)
      |> stub(:stop, fn _id -> :ok end)

      Agents.Mocks.OpencodeClientMock
      |> expect(:health, fn _url -> :ok end)
      |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-broadcast"}} end)
      |> expect(:subscribe_events, fn _url, runner_pid ->
        spawn(fn ->
          Process.sleep(50)

          send(runner_pid, {
            :opencode_event,
            %{
              "type" => "session.status",
              "properties" => %{
                "sessionID" => "sess-broadcast",
                "status" => %{"type" => "busy"}
              }
            }
          })

          Process.sleep(50)

          send(runner_pid, {
            :opencode_event,
            %{
              "type" => "session.status",
              "properties" => %{
                "sessionID" => "sess-broadcast",
                "status" => %{"type" => "idle"}
              }
            }
          })
        end)

        {:ok, self()}
      end)
      |> expect(:send_prompt_async, fn _url, "sess-broadcast", _parts, _opts -> :ok end)

      {:ok, pid} = GenServer.start(TaskRunner, {task.id, opts})
      ref = Process.monitor(pid)

      # Should receive session_id_set broadcast before the task completes
      task_id = task.id

      assert_receive {:task_session_id_set, ^task_id, "sess-broadcast"}, 5000
      assert_receive {:task_status_changed, _, "completed"}, 5000
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5_000
    end
  end

  describe "output caching on failure (AC 5)" do
    test "caches output to DB when task fails via session.error", %{task: task, opts: opts} do
      Agents.Mocks.ContainerProviderMock
      |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "ctr-3", port: 4096}} end)
      |> stub(:stop, fn _id -> :ok end)

      Agents.Mocks.OpencodeClientMock
      |> expect(:health, fn _url -> :ok end)
      |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-fail"}} end)
      |> expect(:subscribe_events, fn _url, runner_pid ->
        spawn(fn ->
          Process.sleep(50)

          # Some output before failure
          send(runner_pid, {
            :opencode_event,
            %{
              "type" => "message.part.updated",
              "properties" => %{
                "part" => %{"id" => "txt-fail", "type" => "text", "text" => "Partial work done"}
              }
            }
          })

          Process.sleep(50)

          # Session error
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
      |> expect(:send_prompt_async, fn _url, "sess-fail", _parts, _opts -> :ok end)

      {:ok, pid} = GenServer.start(TaskRunner, {task.id, opts})
      ref = Process.monitor(pid)

      assert_receive {:task_status_changed, _, "failed"}, 5000
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5_000

      # Assert output was cached in DB despite failure
      updated_task = Repo.get!(TaskSchema, task.id)
      assert updated_task.status == "failed"
      assert updated_task.error == "Model rate limit exceeded"
      assert is_binary(updated_task.output)

      {:ok, output_parts} = Jason.decode(updated_task.output)

      assert Enum.any?(output_parts, fn part ->
               part["type"] == "text" and part["text"] == "Partial work done"
             end)
    end

    test "caches output to DB when task fails via SSE connection error", %{
      task: task,
      opts: opts
    } do
      Agents.Mocks.ContainerProviderMock
      |> expect(:start, fn _image, _opts -> {:ok, %{container_id: "ctr-4", port: 4096}} end)
      |> stub(:stop, fn _id -> :ok end)

      Agents.Mocks.OpencodeClientMock
      |> expect(:health, fn _url -> :ok end)
      |> expect(:create_session, fn _url, _opts -> {:ok, %{"id" => "sess-sse-fail"}} end)
      |> expect(:subscribe_events, fn _url, runner_pid ->
        spawn(fn ->
          Process.sleep(50)

          # Some output before SSE failure
          send(runner_pid, {
            :opencode_event,
            %{
              "type" => "message.part.updated",
              "properties" => %{
                "part" => %{
                  "id" => "txt-sse",
                  "type" => "text",
                  "text" => "Working before disconnect"
                }
              }
            }
          })

          Process.sleep(50)
          send(runner_pid, {:opencode_error, :connection_closed})
        end)

        {:ok, self()}
      end)
      |> expect(:send_prompt_async, fn _url, "sess-sse-fail", _parts, _opts -> :ok end)

      {:ok, pid} = GenServer.start(TaskRunner, {task.id, opts})
      ref = Process.monitor(pid)

      assert_receive {:task_status_changed, _, "failed"}, 5000
      assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5_000

      # Assert output was cached in DB despite SSE failure
      updated_task = Repo.get!(TaskSchema, task.id)
      assert updated_task.status == "failed"
      assert updated_task.error =~ "SSE connection failed"
      assert is_binary(updated_task.output)

      {:ok, output_parts} = Jason.decode(updated_task.output)

      assert Enum.any?(output_parts, fn part ->
               part["type"] == "text" and part["text"] == "Working before disconnect"
             end)
    end
  end
end
