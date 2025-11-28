defmodule Jarga.Chat.Infrastructure.Queries.QueriesTest do
  use Jarga.DataCase, async: true

  alias Jarga.Chat.Infrastructure.Queries.Queries

  import Jarga.ChatFixtures

  @moduledoc """
  Tests for chat-specific query objects.

  Tests query composition and results, not full use cases.
  """

  setup do
    user = Jarga.AccountsFixtures.user_fixture()
    workspace = Jarga.WorkspacesFixtures.workspace_fixture(user)
    project = Jarga.ProjectsFixtures.project_fixture(user, workspace)

    %{user: user, workspace: workspace, project: project}
  end

  describe "session_base/0" do
    test "returns a queryable for sessions" do
      query = Queries.session_base()
      assert %Ecto.Query{} = query
    end
  end

  describe "for_user/2" do
    test "filters sessions by user ID", %{user: user} do
      session1 = chat_session_fixture(%{user_id: user.id})
      other_user = Jarga.AccountsFixtures.user_fixture()
      _session2 = chat_session_fixture(%{user_id: other_user.id})

      results =
        Queries.session_base()
        |> Queries.for_user(user.id)
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == session1.id
    end
  end

  describe "by_id/2" do
    test "filters sessions by ID", %{user: user} do
      session = chat_session_fixture(%{user_id: user.id})

      results =
        Queries.session_base()
        |> Queries.by_id(session.id)
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == session.id
    end
  end

  describe "by_id_and_user/3" do
    test "filters sessions by ID and user (for authorization)", %{user: user} do
      session = chat_session_fixture(%{user_id: user.id})

      results =
        Queries.session_base()
        |> Queries.by_id_and_user(session.id, user.id)
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == session.id
    end

    test "returns empty when user doesn't own session", %{user: user} do
      other_user = Jarga.AccountsFixtures.user_fixture()
      session = chat_session_fixture(%{user_id: other_user.id})

      results =
        Queries.session_base()
        |> Queries.by_id_and_user(session.id, user.id)
        |> Repo.all()

      assert results == []
    end
  end

  describe "with_preloads/1" do
    test "preloads session relationships", %{user: user, workspace: workspace, project: project} do
      session =
        chat_session_fixture(%{
          user_id: user.id,
          workspace_id: workspace.id,
          project_id: project.id
        })

      chat_message_fixture(%{chat_session_id: session.id, role: "user", content: "Hello"})

      [result] =
        Queries.session_base()
        |> Queries.by_id(session.id)
        |> Queries.with_preloads()
        |> Repo.all()

      assert result.user.id == user.id
      assert result.workspace.id == workspace.id
      assert result.project.id == project.id
      assert length(result.messages) == 1
    end
  end

  describe "ordered_by_recent/1" do
    test "orders sessions by most recent first", %{user: user} do
      # Create sessions - they should be ordered by insertion (recent first)
      _session1 = chat_session_fixture(%{user_id: user.id})
      _session2 = chat_session_fixture(%{user_id: user.id})
      _session3 = chat_session_fixture(%{user_id: user.id})

      results =
        Queries.session_base()
        |> Queries.for_user(user.id)
        |> Queries.ordered_by_recent()
        |> Repo.all()

      # Verify we got 3 results and they're ordered by updated_at desc
      assert length(results) == 3

      # Check ordering: each session should have updated_at >= next session
      [first, second, third] = results
      assert DateTime.compare(first.updated_at, second.updated_at) in [:gt, :eq]
      assert DateTime.compare(second.updated_at, third.updated_at) in [:gt, :eq]
    end
  end

  describe "limit_results/2" do
    test "limits number of results", %{user: user} do
      chat_session_fixture(%{user_id: user.id})
      chat_session_fixture(%{user_id: user.id})
      chat_session_fixture(%{user_id: user.id})

      results =
        Queries.session_base()
        |> Queries.for_user(user.id)
        |> Queries.limit_results(2)
        |> Repo.all()

      assert length(results) == 2
    end
  end

  describe "with_message_count/1" do
    test "includes message count for sessions", %{user: user} do
      session1 = chat_session_fixture(%{user_id: user.id})
      session2 = chat_session_fixture(%{user_id: user.id})

      # session1 has 2 messages
      chat_message_fixture(%{chat_session_id: session1.id, role: "user", content: "Hello"})
      chat_message_fixture(%{chat_session_id: session1.id, role: "assistant", content: "Hi"})

      # session2 has 1 message
      chat_message_fixture(%{chat_session_id: session2.id, role: "user", content: "Question"})

      results =
        Queries.session_base()
        |> Queries.for_user(user.id)
        |> Queries.with_message_count()
        |> Repo.all()

      result1 = Enum.find(results, &(&1.id == session1.id))
      result2 = Enum.find(results, &(&1.id == session2.id))

      assert result1.message_count == 2
      assert result2.message_count == 1
    end
  end

  describe "message_base/0" do
    test "returns a queryable for messages" do
      query = Queries.message_base()
      assert %Ecto.Query{} = query
    end
  end

  describe "for_session/2" do
    test "filters messages by session ID", %{user: user} do
      session1 = chat_session_fixture(%{user_id: user.id})
      session2 = chat_session_fixture(%{user_id: user.id})

      message1 =
        chat_message_fixture(%{chat_session_id: session1.id, role: "user", content: "Q1"})

      _message2 =
        chat_message_fixture(%{chat_session_id: session2.id, role: "user", content: "Q2"})

      results =
        Queries.message_base()
        |> Queries.for_session(session1.id)
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == message1.id
    end
  end

  describe "messages_ordered/0" do
    test "orders messages chronologically (oldest first)", %{user: user} do
      session = chat_session_fixture(%{user_id: user.id})

      _message1 =
        chat_message_fixture(%{chat_session_id: session.id, role: "user", content: "First"})

      _message2 =
        chat_message_fixture(%{chat_session_id: session.id, role: "assistant", content: "Second"})

      _message3 =
        chat_message_fixture(%{chat_session_id: session.id, role: "user", content: "Third"})

      results = Queries.messages_ordered() |> Repo.all()

      # Verify we got 3 results and they're ordered by inserted_at asc (oldest first)
      assert length(results) == 3

      # Check ordering: each message should have inserted_at <= next message
      [first, second, third] = results
      assert DateTime.compare(first.inserted_at, second.inserted_at) in [:lt, :eq]
      assert DateTime.compare(second.inserted_at, third.inserted_at) in [:lt, :eq]
    end
  end

  describe "first_message_content/1" do
    test "returns first message content for session", %{user: user} do
      session = chat_session_fixture(%{user_id: user.id})

      chat_message_fixture(%{chat_session_id: session.id, role: "user", content: "First message"})

      chat_message_fixture(%{
        chat_session_id: session.id,
        role: "assistant",
        content: "Second message"
      })

      content =
        session.id
        |> Queries.first_message_content()
        |> Repo.one()

      assert content == "First message"
    end

    test "returns nil when session has no messages", %{user: user} do
      session = chat_session_fixture(%{user_id: user.id})

      content =
        session.id
        |> Queries.first_message_content()
        |> Repo.one()

      assert is_nil(content)
    end
  end

  describe "message_by_id_and_user/2" do
    test "returns message when user owns the session", %{user: user} do
      session = chat_session_fixture(%{user_id: user.id})

      message =
        chat_message_fixture(%{chat_session_id: session.id, role: "user", content: "Test"})

      result =
        message.id
        |> Queries.message_by_id_and_user(user.id)
        |> Repo.one()

      assert result.id == message.id
    end

    test "returns nil when user doesn't own the session", %{user: user} do
      other_user = Jarga.AccountsFixtures.user_fixture()
      session = chat_session_fixture(%{user_id: other_user.id})

      message =
        chat_message_fixture(%{chat_session_id: session.id, role: "user", content: "Test"})

      result =
        message.id
        |> Queries.message_by_id_and_user(user.id)
        |> Repo.one()

      assert is_nil(result)
    end
  end
end
