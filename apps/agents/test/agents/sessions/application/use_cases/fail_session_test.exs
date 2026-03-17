defmodule Agents.Sessions.Application.UseCases.FailSessionTest do
  use Agents.DataCase, async: true

  import Agents.SessionsFixtures

  alias Agents.Repo
  alias Agents.Sessions.Application.UseCases.FailSession
  alias Agents.Sessions.Infrastructure.Schemas.SessionSchema

  # FailSession does not emit events, so no TestEventBus needed.
  @user_id Ecto.UUID.generate()

  describe "execute/2 happy path" do
    test "fails an active session" do
      session = session_fixture(%{user_id: @user_id, status: "active"})

      assert {:ok, updated} = FailSession.execute(session.id)

      assert updated.status == "failed"
    end

    test "fails a paused session" do
      session = session_fixture(%{user_id: @user_id, status: "paused"})

      assert {:ok, updated} = FailSession.execute(session.id)

      assert updated.status == "failed"
    end

    test "persists the failed state to the database" do
      session = session_fixture(%{user_id: @user_id, status: "active"})

      assert {:ok, _updated} = FailSession.execute(session.id)

      persisted = Repo.get!(SessionSchema, session.id)
      assert persisted.status == "failed"
    end
  end

  describe "execute/2 invalid transition" do
    test "returns error when session is already completed" do
      session = session_fixture(%{user_id: @user_id, status: "completed"})

      assert {:error, :invalid_transition} = FailSession.execute(session.id)
    end

    test "returns error when session is already failed" do
      session = session_fixture(%{user_id: @user_id, status: "failed"})

      assert {:error, :invalid_transition} = FailSession.execute(session.id)
    end
  end

  describe "execute/2 not found" do
    test "returns error when session does not exist" do
      assert {:error, :not_found} = FailSession.execute(Ecto.UUID.generate())
    end
  end
end
