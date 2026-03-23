defmodule Agents.Sessions.Application.UseCases.ResumeSessionTest do
  use Agents.DataCase, async: true

  import Agents.SessionsFixtures

  alias Agents.Repo
  alias Agents.Sessions.Application.UseCases.ResumeSession
  alias Agents.Sessions.Domain.Events.SessionResumed
  alias Agents.Sessions.Infrastructure.Schemas.{InteractionSchema, SessionSchema, TaskSchema}
  alias Perme8.Events.TestEventBus

  import Ecto.Query

  @user_id Ecto.UUID.generate()

  defmodule QueueOrchestratorStub do
    def notify_session_activity(user_id, session_id) do
      send(Process.get(:test_pid), {:session_activity, user_id, session_id})
      :ok
    end
  end

  setup do
    TestEventBus.start_global()
    :ok
  end

  describe "execute/4 happy path" do
    test "resumes a paused session" do
      session = session_fixture(%{user_id: @user_id, status: "paused"})
      instruction = "Continue working on the feature"

      assert {:ok, updated} =
               ResumeSession.execute(session.id, @user_id, instruction, event_bus: TestEventBus)

      assert updated.status == "active"
      assert updated.resumed_at != nil
    end

    test "persists the resumed state to the database" do
      session = session_fixture(%{user_id: @user_id, status: "paused"})

      assert {:ok, _updated} =
               ResumeSession.execute(session.id, @user_id, "Resume", event_bus: TestEventBus)

      persisted = Repo.get!(SessionSchema, session.id)
      assert persisted.status == "active"
      assert persisted.resumed_at != nil
    end

    test "notifies queue orchestrator of renewed session activity" do
      session = session_fixture(%{user_id: @user_id, status: "paused"})
      Process.put(:test_pid, self())
      session_id = session.id

      assert {:ok, _updated} =
               ResumeSession.execute(session_id, @user_id, "Resume",
                 event_bus: TestEventBus,
                 queue_orchestrator: QueueOrchestratorStub
               )

      assert_receive {:session_activity, @user_id, ^session_id}
    end
  end

  describe "execute/4 invalid transition" do
    test "returns error when session is already active" do
      session = session_fixture(%{user_id: @user_id, status: "active"})

      assert {:error, :invalid_transition} =
               ResumeSession.execute(session.id, @user_id, "Resume", event_bus: TestEventBus)
    end

    test "returns error when session is completed" do
      session = session_fixture(%{user_id: @user_id, status: "completed"})

      assert {:error, :invalid_transition} =
               ResumeSession.execute(session.id, @user_id, "Resume", event_bus: TestEventBus)
    end

    test "returns error when session is failed" do
      session = session_fixture(%{user_id: @user_id, status: "failed"})

      assert {:error, :invalid_transition} =
               ResumeSession.execute(session.id, @user_id, "Resume", event_bus: TestEventBus)
    end
  end

  describe "execute/4 not found" do
    test "returns error when session does not exist" do
      assert {:error, :not_found} =
               ResumeSession.execute(Ecto.UUID.generate(), @user_id, "Resume",
                 event_bus: TestEventBus
               )
    end

    test "returns error when session belongs to a different user" do
      other_user_id = Ecto.UUID.generate()
      session = session_fixture(%{user_id: other_user_id, status: "paused"})

      assert {:error, :not_found} =
               ResumeSession.execute(session.id, @user_id, "Resume", event_bus: TestEventBus)
    end
  end

  describe "execute/4 task creation" do
    test "creates a queued task with the resume instruction" do
      session = session_fixture(%{user_id: @user_id, status: "paused"})
      instruction = "Fix the failing test"

      assert {:ok, _updated} =
               ResumeSession.execute(session.id, @user_id, instruction, event_bus: TestEventBus)

      tasks =
        Repo.all(
          from(t in TaskSchema,
            where: t.session_ref_id == ^session.id and t.user_id == ^@user_id
          )
        )

      assert [task] = tasks
      assert task.instruction == "Fix the failing test"
      assert task.status == "queued"
      assert task.queued_at != nil
    end
  end

  describe "execute/4 interaction creation" do
    test "stores the resume instruction as an inbound interaction" do
      session = session_fixture(%{user_id: @user_id, status: "paused"})
      instruction = "Continue with the next step"

      assert {:ok, _updated} =
               ResumeSession.execute(session.id, @user_id, instruction, event_bus: TestEventBus)

      interactions =
        Repo.all(from(i in InteractionSchema, where: i.session_id == ^session.id))

      assert [interaction] = interactions
      assert interaction.type == "instruction"
      assert interaction.direction == "inbound"
      assert interaction.payload == %{"text" => instruction}
    end
  end

  describe "execute/4 event emission" do
    test "emits SessionResumed event on success" do
      session = session_fixture(%{user_id: @user_id, status: "paused"})

      assert {:ok, _updated} =
               ResumeSession.execute(session.id, @user_id, "Resume", event_bus: TestEventBus)

      events = TestEventBus.get_events()
      assert [%SessionResumed{} = event] = events
      assert event.session_id == session.id
      assert event.user_id == @user_id
      assert event.aggregate_id == session.id
      assert event.resumed_at != nil
    end

    test "does not emit event on invalid transition" do
      session = session_fixture(%{user_id: @user_id, status: "active"})

      assert {:error, :invalid_transition} =
               ResumeSession.execute(session.id, @user_id, "Resume", event_bus: TestEventBus)

      assert TestEventBus.get_events() == []
    end
  end
end
