defmodule Jarga.Chat.Infrastructure.Repositories.SessionRepositoryTest do
  @moduledoc """
  Tests for SessionRepository data access operations.

  Tests repository functions that interact with the database,
  ensuring correct data retrieval and composition of queries.
  """
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.ChatFixtures

  alias Jarga.Chat.Infrastructure.Repositories.SessionRepository

  describe "list_all_sessions/2" do
    test "returns all sessions across all users" do
      user1 = user_fixture()
      user2 = user_fixture(%{email: "other@example.com"})

      session1 = chat_session_fixture(user: user1, title: "User 1 Chat")
      session2 = chat_session_fixture(user: user2, title: "User 2 Chat")

      results = SessionRepository.list_all_sessions(50)

      result_ids = Enum.map(results, & &1.id)
      assert session1.id in result_ids
      assert session2.id in result_ids
    end

    test "returns sessions ordered by most recent first" do
      user = user_fixture()

      _session1 = chat_session_fixture(user: user, title: "Oldest")
      _session2 = chat_session_fixture(user: user, title: "Middle")
      _session3 = chat_session_fixture(user: user, title: "Newest")

      results = SessionRepository.list_all_sessions(50)

      assert length(results) == 3

      # Verify they're ordered by updated_at descending
      [first, second, third] = results
      assert first.updated_at >= second.updated_at
      assert second.updated_at >= third.updated_at
    end

    test "respects the limit parameter" do
      user = user_fixture()

      for i <- 1..5 do
        chat_session_fixture(user: user, title: "Chat #{i}")
      end

      results = SessionRepository.list_all_sessions(3)

      assert length(results) == 3
    end

    test "includes message count for each session" do
      user = user_fixture()
      session = chat_session_fixture(user: user)

      chat_message_fixture(chat_session: session, role: "user", content: "Msg 1")
      chat_message_fixture(chat_session: session, role: "assistant", content: "Msg 2")

      results = SessionRepository.list_all_sessions(50)

      result = Enum.find(results, &(&1.id == session.id))
      assert result.message_count == 2
    end

    test "returns empty list when no sessions exist" do
      results = SessionRepository.list_all_sessions(50)
      assert results == []
    end
  end
end
