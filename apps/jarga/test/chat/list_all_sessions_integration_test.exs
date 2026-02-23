defmodule Jarga.Chat.ListAllSessionsIntegrationTest do
  @moduledoc """
  Integration tests for the Chat.list_all_sessions/1 public API.

  Tests the complete stack from facade through use case to database.
  """
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.ChatFixtures

  describe "list_all_sessions/1" do
    test "returns all sessions across all users via the public API" do
      user1 = user_fixture()
      user2 = user_fixture(%{email: "other@example.com"})

      session1 = chat_session_fixture(user: user1, title: "User 1 Chat")
      session2 = chat_session_fixture(user: user2, title: "User 2 Chat")

      assert {:ok, sessions} = Jarga.Chat.list_all_sessions()

      session_ids = Enum.map(sessions, & &1.id)
      assert session1.id in session_ids
      assert session2.id in session_ids
    end

    test "accepts limit option" do
      user = user_fixture()

      for i <- 1..5 do
        chat_session_fixture(user: user, title: "Chat #{i}")
      end

      assert {:ok, sessions} = Jarga.Chat.list_all_sessions(limit: 3)

      assert length(sessions) == 3
    end

    test "returns empty list when no sessions exist" do
      assert {:ok, []} = Jarga.Chat.list_all_sessions()
    end
  end
end
