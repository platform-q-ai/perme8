defmodule Agents.Sessions.Application.UseCases.PauseSessionTest do
  use Agents.DataCase, async: true

  import Agents.SessionsFixtures

  alias Agents.Repo
  alias Agents.Sessions.Application.UseCases.PauseSession
  alias Agents.Sessions.Domain.Events.SessionPaused
  alias Agents.Sessions.Infrastructure.Schemas.SessionSchema
  alias Perme8.Events.TestEventBus

  @user_id Ecto.UUID.generate()

  setup do
    TestEventBus.start_global()
    :ok
  end

  describe "execute/3 happy path" do
    test "pauses an active session" do
      session = session_fixture(%{user_id: @user_id, status: "active"})

      assert {:ok, updated} = PauseSession.execute(session.id, @user_id, event_bus: TestEventBus)

      assert updated.status == "paused"
      assert updated.container_status == "stopped"
      assert updated.paused_at != nil
    end

    test "persists the paused state to the database" do
      session = session_fixture(%{user_id: @user_id, status: "active"})

      assert {:ok, _updated} = PauseSession.execute(session.id, @user_id, event_bus: TestEventBus)

      persisted = Repo.get!(SessionSchema, session.id)
      assert persisted.status == "paused"
      assert persisted.container_status == "stopped"
      assert persisted.paused_at != nil
    end
  end

  describe "execute/3 invalid transition" do
    test "returns error when session is already paused" do
      session = session_fixture(%{user_id: @user_id, status: "paused"})

      assert {:error, :invalid_transition} =
               PauseSession.execute(session.id, @user_id, event_bus: TestEventBus)
    end

    test "returns error when session is completed" do
      session = session_fixture(%{user_id: @user_id, status: "completed"})

      assert {:error, :invalid_transition} =
               PauseSession.execute(session.id, @user_id, event_bus: TestEventBus)
    end

    test "returns error when session is failed" do
      session = session_fixture(%{user_id: @user_id, status: "failed"})

      assert {:error, :invalid_transition} =
               PauseSession.execute(session.id, @user_id, event_bus: TestEventBus)
    end
  end

  describe "execute/3 not found" do
    test "returns error when session does not exist" do
      assert {:error, :not_found} =
               PauseSession.execute(Ecto.UUID.generate(), @user_id, event_bus: TestEventBus)
    end

    test "returns error when session belongs to a different user" do
      other_user_id = Ecto.UUID.generate()
      session = session_fixture(%{user_id: other_user_id, status: "active"})

      assert {:error, :not_found} =
               PauseSession.execute(session.id, @user_id, event_bus: TestEventBus)
    end
  end

  describe "execute/3 event emission" do
    test "emits SessionPaused event on success" do
      session = session_fixture(%{user_id: @user_id, status: "active"})

      assert {:ok, _updated} = PauseSession.execute(session.id, @user_id, event_bus: TestEventBus)

      events = TestEventBus.get_events()
      assert [%SessionPaused{} = event] = events
      assert event.session_id == session.id
      assert event.user_id == @user_id
      assert event.aggregate_id == session.id
      assert event.paused_at != nil
    end

    test "does not emit event on invalid transition" do
      session = session_fixture(%{user_id: @user_id, status: "paused"})

      assert {:error, :invalid_transition} =
               PauseSession.execute(session.id, @user_id, event_bus: TestEventBus)

      assert TestEventBus.get_events() == []
    end

    test "does not emit event when session not found" do
      assert {:error, :not_found} =
               PauseSession.execute(Ecto.UUID.generate(), @user_id, event_bus: TestEventBus)

      assert TestEventBus.get_events() == []
    end
  end
end
