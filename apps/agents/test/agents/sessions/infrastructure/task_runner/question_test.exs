defmodule Agents.Sessions.Infrastructure.TaskRunner.QuestionTest do
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

  defp maybe_complete_session(false, _runner_pid), do: :noop

  defp maybe_complete_session(true, runner_pid) do
    Process.sleep(100)

    send(runner_pid, {
      :opencode_event,
      %{
        "type" => "session.status",
        "properties" => %{"sessionID" => "sess-1", "status" => %{"type" => "idle"}}
      }
    })
  end

  defp start_runner_with_question(task, opts \\ []) do
    test_pid = self()
    question_event_delay = Keyword.get(opts, :question_event_delay, 50)
    complete_after_question = Keyword.get(opts, :complete_after_question, false)

    Agents.Mocks.TaskRepositoryMock
    |> stub(:get_task, fn _id -> task end)
    |> stub(:update_task_status, fn _task, attrs ->
      if Map.has_key?(attrs, :pending_question) do
        send(test_pid, {:question_persisted, attrs.pending_question})
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
        Process.sleep(question_event_delay)

        # Session starts running
        send(runner_pid, {
          :opencode_event,
          %{
            "type" => "session.status",
            "properties" => %{"sessionID" => "sess-1", "status" => %{"type" => "busy"}}
          }
        })

        Process.sleep(50)

        # Question asked
        send(runner_pid, {
          :opencode_event,
          %{
            "type" => "question.asked",
            "properties" => %{
              "id" => "q-request-1",
              "sessionID" => "sess-1",
              "questions" => [
                %{
                  "question" => "Which option?",
                  "header" => "Choose",
                  "options" => [
                    %{"label" => "Option A", "description" => "First option"},
                    %{"label" => "Option B", "description" => "Second option"}
                  ]
                }
              ]
            }
          }
        })

        maybe_complete_session(complete_after_question, runner_pid)
      end)

      {:ok, self()}
    end)
    |> expect(:send_prompt_async, fn _url, "sess-1", _parts, _opts -> :ok end)
  end

  describe "question.asked event" do
    test "persists pending question to database", %{task: task} do
      start_runner_with_question(task)

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

      on_exit(fn ->
        try do
          if Process.alive?(pid), do: GenServer.stop(pid, :normal, 5_000)
        rescue
          _ -> :ok
        end
      end)

      assert_receive {:question_persisted, question_data}, 5000
      assert question_data["request_id"] == "q-request-1"
      assert question_data["session_id"] == "sess-1"
      assert length(question_data["questions"]) == 1
      assert question_data["asked_at"] != nil
    end

    test "broadcasts question event via PubSub", %{task: task} do
      start_runner_with_question(task)

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

      on_exit(fn ->
        try do
          if Process.alive?(pid), do: GenServer.stop(pid, :normal, 5_000)
        rescue
          _ -> :ok
        end
      end)

      assert_receive {:task_event, _, %{"type" => "question.asked"}}, 5000
    end
  end

  describe "question timeout" do
    test "auto-rejects question after timeout", %{task: task} do
      test_pid = self()

      start_runner_with_question(task)

      # Expect reject_question to be called when timeout fires
      Agents.Mocks.OpencodeClientMock
      |> expect(:reject_question, fn _url, "q-request-1", _opts ->
        send(test_pid, :question_auto_rejected)
        :ok
      end)

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

      on_exit(fn ->
        try do
          if Process.alive?(pid), do: GenServer.stop(pid, :normal, 5_000)
        rescue
          _ -> :ok
        end
      end)

      # Wait for the question to be persisted first
      assert_receive {:question_persisted, %{"request_id" => "q-request-1"}}, 5000

      # Now send the timeout message directly to the runner (instead of waiting for real timeout)
      send(pid, :question_timeout)

      # The question should be auto-rejected
      assert_receive :question_auto_rejected, 5000

      # Question stays in DB but marked as rejected (so UI can still show it)
      assert_receive {:question_persisted, %{"rejected" => true, "request_id" => "q-request-1"}},
                     5000
    end
  end

  describe "answer_question" do
    test "clears pending question from database after answer", %{task: task} do
      test_pid = self()

      start_runner_with_question(task)

      Agents.Mocks.OpencodeClientMock
      |> expect(:reply_question, fn _url, "q-request-1", [["Option A"]], _opts ->
        send(test_pid, :question_answered)
        :ok
      end)

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

      on_exit(fn ->
        try do
          if Process.alive?(pid), do: GenServer.stop(pid, :normal, 5_000)
        rescue
          _ -> :ok
        end
      end)

      # Wait for question to arrive
      assert_receive {:question_persisted, %{"request_id" => "q-request-1"}}, 5000

      # Answer the question
      GenServer.call(pid, {:answer_question, "q-request-1", [["Option A"]]})

      assert_receive :question_answered, 5000
      # Pending question should be cleared
      assert_receive {:question_persisted, nil}, 5000
    end
  end

  describe "reject_question" do
    test "marks pending question as rejected in database", %{task: task} do
      test_pid = self()

      start_runner_with_question(task)

      Agents.Mocks.OpencodeClientMock
      |> expect(:reject_question, fn _url, "q-request-1", _opts ->
        send(test_pid, :question_rejected)
        :ok
      end)

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

      on_exit(fn ->
        try do
          if Process.alive?(pid), do: GenServer.stop(pid, :normal, 5_000)
        rescue
          _ -> :ok
        end
      end)

      # Wait for question to arrive
      assert_receive {:question_persisted, %{"request_id" => "q-request-1"}}, 5000

      # Reject the question
      GenServer.call(pid, {:reject_question, "q-request-1"})

      assert_receive :question_rejected, 5000
      # Question stays in DB but marked as rejected (so UI can still show it)
      assert_receive {:question_persisted, %{"rejected" => true, "request_id" => "q-request-1"}},
                     5000
    end
  end

  describe "empty question auto-rejection" do
    defp start_runner_with_empty_question(task, question_props) do
      test_pid = self()

      Agents.Mocks.TaskRepositoryMock
      |> stub(:get_task, fn _id -> task end)
      |> stub(:update_task_status, fn _task, attrs ->
        if Map.has_key?(attrs, :pending_question) do
          send(test_pid, {:question_persisted, attrs.pending_question})
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
              "type" => "session.status",
              "properties" => %{"sessionID" => "sess-1", "status" => %{"type" => "busy"}}
            }
          })

          Process.sleep(50)

          send(runner_pid, {
            :opencode_event,
            %{"type" => "question.asked", "properties" => question_props}
          })
        end)

        {:ok, self()}
      end)
      |> expect(:send_prompt_async, fn _url, "sess-1", _parts, _opts -> :ok end)
    end

    test "auto-rejects question with empty questions list", %{task: task} do
      test_pid = self()

      start_runner_with_empty_question(task, %{
        "id" => "q-empty-1",
        "sessionID" => "sess-1",
        "questions" => []
      })

      Agents.Mocks.OpencodeClientMock
      |> expect(:reject_question, fn _url, "q-empty-1", _opts ->
        send(test_pid, :empty_question_rejected)
        :ok
      end)

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

      on_exit(fn ->
        try do
          if Process.alive?(pid), do: GenServer.stop(pid, :normal, 5_000)
        rescue
          _ -> :ok
        end
      end)

      assert_receive :empty_question_rejected, 5000
      # Should NOT persist a pending question for empty questions
      refute_receive {:question_persisted, _}, 500
    end

    test "auto-rejects question with nil questions", %{task: task} do
      test_pid = self()

      start_runner_with_empty_question(task, %{
        "id" => "q-nil-1",
        "sessionID" => "sess-1",
        "questions" => nil
      })

      Agents.Mocks.OpencodeClientMock
      |> expect(:reject_question, fn _url, "q-nil-1", _opts ->
        send(test_pid, :nil_question_rejected)
        :ok
      end)

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

      on_exit(fn ->
        try do
          if Process.alive?(pid), do: GenServer.stop(pid, :normal, 5_000)
        rescue
          _ -> :ok
        end
      end)

      assert_receive :nil_question_rejected, 5000
      refute_receive {:question_persisted, _}, 500
    end

    test "auto-rejects question with missing questions key", %{task: task} do
      test_pid = self()

      start_runner_with_empty_question(task, %{
        "id" => "q-missing-1",
        "sessionID" => "sess-1"
      })

      Agents.Mocks.OpencodeClientMock
      |> expect(:reject_question, fn _url, "q-missing-1", _opts ->
        send(test_pid, :missing_question_rejected)
        :ok
      end)

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

      on_exit(fn ->
        try do
          if Process.alive?(pid), do: GenServer.stop(pid, :normal, 5_000)
        rescue
          _ -> :ok
        end
      end)

      assert_receive :missing_question_rejected, 5000
      refute_receive {:question_persisted, _}, 500
    end
  end
end
