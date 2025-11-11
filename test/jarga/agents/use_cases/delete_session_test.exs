defmodule Jarga.Agents.UseCases.DeleteSessionTest do
  @moduledoc """
  Tests for DeleteSession use case.
  """
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.AgentsFixtures

  alias Jarga.Agents.UseCases.DeleteSession
  alias Jarga.Repo

  describe "execute/2" do
    test "deletes a session and its messages" do
      user = user_fixture()
      session = chat_session_fixture(user: user)

      # Add messages
      msg1 = chat_message_fixture(chat_session: session)
      msg2 = chat_message_fixture(chat_session: session)

      assert {:ok, deleted_session} = DeleteSession.execute(session.id, user.id)

      assert deleted_session.id == session.id

      # Session should be deleted
      assert Repo.get(Jarga.Agents.ChatSession, session.id) == nil

      # Messages should be deleted (cascade)
      assert Repo.get(Jarga.Agents.ChatMessage, msg1.id) == nil
      assert Repo.get(Jarga.Agents.ChatMessage, msg2.id) == nil
    end

    test "returns error when session does not exist" do
      user = user_fixture()
      fake_id = Ecto.UUID.generate()

      assert {:error, :not_found} = DeleteSession.execute(fake_id, user.id)
    end

    test "returns error when user does not own the session" do
      user1 = user_fixture()
      user2 = user_fixture(%{email: "other@example.com"})

      session = chat_session_fixture(user: user1)

      # User2 tries to delete user1's session
      assert {:error, :not_found} = DeleteSession.execute(session.id, user2.id)

      # Session should still exist
      assert Repo.get(Jarga.Agents.ChatSession, session.id) != nil
    end

    test "only deletes messages from the specified session" do
      user = user_fixture()
      session1 = chat_session_fixture(user: user)
      session2 = chat_session_fixture(user: user)

      msg1 = chat_message_fixture(chat_session: session1, content: "Session 1 message")
      msg2 = chat_message_fixture(chat_session: session2, content: "Session 2 message")

      # Delete session1
      assert {:ok, _} = DeleteSession.execute(session1.id, user.id)

      # Session1 and its message should be deleted
      assert Repo.get(Jarga.Agents.ChatSession, session1.id) == nil
      assert Repo.get(Jarga.Agents.ChatMessage, msg1.id) == nil

      # Session2 and its message should still exist
      assert Repo.get(Jarga.Agents.ChatSession, session2.id) != nil
      assert Repo.get(Jarga.Agents.ChatMessage, msg2.id) != nil
    end
  end
end
