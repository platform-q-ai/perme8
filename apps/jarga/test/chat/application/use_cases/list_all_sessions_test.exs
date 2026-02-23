defmodule Jarga.Chat.Application.UseCases.ListAllSessionsTest do
  @moduledoc """
  Tests for ListAllSessions use case.

  This use case lists all chat sessions across all users,
  intended for admin/dashboard views where no user filtering is needed.
  """
  use Jarga.DataCase, async: true

  import Jarga.AccountsFixtures
  import Jarga.ChatFixtures

  alias Jarga.Chat.Application.UseCases.ListAllSessions

  describe "execute/1" do
    test "returns all sessions across all users" do
      user1 = user_fixture()
      user2 = user_fixture(%{email: "other@example.com"})

      session1 = chat_session_fixture(user: user1, title: "User 1 Chat")
      session2 = chat_session_fixture(user: user2, title: "User 2 Chat")

      assert {:ok, sessions} = ListAllSessions.execute()

      session_ids = Enum.map(sessions, & &1.id)
      assert session1.id in session_ids
      assert session2.id in session_ids
    end

    test "returns sessions ordered by most recent first" do
      user = user_fixture()

      session1 = chat_session_fixture(user: user, title: "Oldest")
      session2 = chat_session_fixture(user: user, title: "Middle")
      session3 = chat_session_fixture(user: user, title: "Newest")

      assert {:ok, sessions} = ListAllSessions.execute()

      assert length(sessions) == 3

      # Verify they're ordered by updated_at descending
      assert Enum.at(sessions, 0).updated_at >= Enum.at(sessions, 1).updated_at
      assert Enum.at(sessions, 1).updated_at >= Enum.at(sessions, 2).updated_at

      # Verify all sessions are present
      session_ids = Enum.map(sessions, & &1.id)
      assert session1.id in session_ids
      assert session2.id in session_ids
      assert session3.id in session_ids
    end

    test "respects :limit option with default of 50" do
      user = user_fixture()

      for i <- 1..10 do
        chat_session_fixture(user: user, title: "Chat #{i}")
      end

      assert {:ok, sessions} = ListAllSessions.execute(limit: 5)

      assert length(sessions) == 5
    end

    test "includes message count for each session" do
      user = user_fixture()
      session = chat_session_fixture(user: user)

      chat_message_fixture(chat_session: session, role: "user", content: "Message 1")
      chat_message_fixture(chat_session: session, role: "assistant", content: "Message 2")
      chat_message_fixture(chat_session: session, role: "user", content: "Message 3")

      assert {:ok, sessions} = ListAllSessions.execute()

      session_with_count = Enum.find(sessions, &(&1.id == session.id))
      assert session_with_count.message_count == 3
    end

    test "includes first message preview" do
      user = user_fixture()
      session = chat_session_fixture(user: user)

      chat_message_fixture(chat_session: session, role: "user", content: "What is the weather?")
      chat_message_fixture(chat_session: session, role: "assistant", content: "It's sunny!")

      assert {:ok, sessions} = ListAllSessions.execute()

      session_with_preview = Enum.find(sessions, &(&1.id == session.id))
      assert session_with_preview.preview == "What is the weather?"
    end

    test "preview is truncated to 100 characters" do
      user = user_fixture()
      session = chat_session_fixture(user: user)

      long_message = String.duplicate("a", 150)
      chat_message_fixture(chat_session: session, role: "user", content: long_message)

      assert {:ok, sessions} = ListAllSessions.execute()

      session_with_preview = Enum.find(sessions, &(&1.id == session.id))
      # 100 + "..."
      assert String.length(session_with_preview.preview) <= 103
      assert String.ends_with?(session_with_preview.preview, "...")
    end

    test "returns empty list when no sessions exist" do
      assert {:ok, []} = ListAllSessions.execute()
    end
  end
end
