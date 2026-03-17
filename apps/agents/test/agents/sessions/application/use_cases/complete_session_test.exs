defmodule Agents.Sessions.Application.UseCases.CompleteSessionTest do
  use Agents.DataCase, async: true

  import Agents.SessionsFixtures

  alias Agents.Repo
  alias Agents.Sessions.Application.UseCases.CompleteSession
  alias Agents.Sessions.Infrastructure.Schemas.SessionSchema

  # CompleteSession does not emit events, so no TestEventBus needed.
  # However, we still provide a user_id for session fixtures.
  @user_id Ecto.UUID.generate()

  describe "execute/2 happy path" do
    test "completes an active session" do
      session = session_fixture(%{user_id: @user_id, status: "active"})

      assert {:ok, updated} = CompleteSession.execute(session.id)

      assert updated.status == "completed"
    end

    test "persists the completed state to the database" do
      session = session_fixture(%{user_id: @user_id, status: "active"})

      assert {:ok, _updated} = CompleteSession.execute(session.id)

      persisted = Repo.get!(SessionSchema, session.id)
      assert persisted.status == "completed"
    end
  end

  describe "execute/2 invalid transition" do
    test "returns error when session is paused" do
      session = session_fixture(%{user_id: @user_id, status: "paused"})

      assert {:error, :invalid_transition} = CompleteSession.execute(session.id)
    end

    test "returns error when session is already completed" do
      session = session_fixture(%{user_id: @user_id, status: "completed"})

      assert {:error, :invalid_transition} = CompleteSession.execute(session.id)
    end

    test "returns error when session is failed" do
      session = session_fixture(%{user_id: @user_id, status: "failed"})

      assert {:error, :invalid_transition} = CompleteSession.execute(session.id)
    end
  end

  describe "execute/2 not found" do
    test "returns error when session does not exist" do
      assert {:error, :not_found} = CompleteSession.execute(Ecto.UUID.generate())
    end
  end
end
