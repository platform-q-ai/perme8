defmodule Agents.Sessions.Application.SessionTransitionTest do
  use Agents.DataCase, async: true

  import Agents.SessionsFixtures

  alias Agents.Sessions.Application.SessionTransition

  @user_id Ecto.UUID.generate()

  describe "with_session_transition/4 using get_session (no user scoping)" do
    test "returns {:ok, session} when transition is valid" do
      session = session_fixture(%{user_id: @user_id, status: "active"})

      assert {:ok, fetched} = SessionTransition.with_session_transition(session.id, "completed")
      assert fetched.id == session.id
    end

    test "returns {:error, :not_found} when session does not exist" do
      assert {:error, :not_found} =
               SessionTransition.with_session_transition(Ecto.UUID.generate(), "completed")
    end

    test "returns {:error, :invalid_transition} when transition is not allowed" do
      session = session_fixture(%{user_id: @user_id, status: "paused"})

      assert {:error, :invalid_transition} =
               SessionTransition.with_session_transition(session.id, "completed")
    end
  end

  describe "with_session_transition/5 using get_session_for_user (user scoping)" do
    test "returns {:ok, session} when transition is valid and user matches" do
      session = session_fixture(%{user_id: @user_id, status: "active"})

      assert {:ok, fetched} =
               SessionTransition.with_session_transition(session.id, @user_id, "paused")

      assert fetched.id == session.id
    end

    test "returns {:error, :not_found} when session does not exist" do
      assert {:error, :not_found} =
               SessionTransition.with_session_transition(
                 Ecto.UUID.generate(),
                 @user_id,
                 "paused"
               )
    end

    test "returns {:error, :not_found} when session belongs to different user" do
      other_user_id = Ecto.UUID.generate()
      session = session_fixture(%{user_id: other_user_id, status: "active"})

      assert {:error, :not_found} =
               SessionTransition.with_session_transition(session.id, @user_id, "paused")
    end

    test "returns {:error, :invalid_transition} when transition is not allowed" do
      session = session_fixture(%{user_id: @user_id, status: "paused"})

      assert {:error, :invalid_transition} =
               SessionTransition.with_session_transition(session.id, @user_id, "paused")
    end
  end

  describe "callback function" do
    test "invokes callback with session on valid transition (no user scoping)" do
      session = session_fixture(%{user_id: @user_id, status: "active"})

      assert {:ok, fetched} =
               SessionTransition.with_session_transition(session.id, "completed", fn s ->
                 {:ok, s}
               end)

      assert fetched.id == session.id
    end

    test "invokes callback with session on valid transition (user scoping)" do
      session = session_fixture(%{user_id: @user_id, status: "active"})

      assert {:ok, fetched} =
               SessionTransition.with_session_transition(
                 session.id,
                 @user_id,
                 "paused",
                 fn s -> {:ok, s} end
               )

      assert fetched.id == session.id
    end

    test "does not invoke callback on invalid transition" do
      session = session_fixture(%{user_id: @user_id, status: "completed"})

      callback = fn _session ->
        flunk("Callback should not be invoked on invalid transition")
      end

      assert {:error, :invalid_transition} =
               SessionTransition.with_session_transition(session.id, "active", callback)
    end

    test "does not invoke callback when session not found" do
      callback = fn _session ->
        flunk("Callback should not be invoked when session not found")
      end

      assert {:error, :not_found} =
               SessionTransition.with_session_transition(
                 Ecto.UUID.generate(),
                 "completed",
                 callback
               )
    end
  end

  describe "session_repo injection" do
    test "accepts custom session_repo via opts (no user scoping)" do
      session = session_fixture(%{user_id: @user_id, status: "active"})

      assert {:ok, _} =
               SessionTransition.with_session_transition(session.id, "completed",
                 session_repo: Agents.Sessions.Infrastructure.Repositories.SessionRepository
               )
    end

    test "accepts custom session_repo via opts (user scoping)" do
      session = session_fixture(%{user_id: @user_id, status: "active"})

      assert {:ok, _} =
               SessionTransition.with_session_transition(session.id, @user_id, "paused",
                 session_repo: Agents.Sessions.Infrastructure.Repositories.SessionRepository
               )
    end
  end
end
