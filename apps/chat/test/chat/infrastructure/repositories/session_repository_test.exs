defmodule Chat.Infrastructure.Repositories.SessionRepositoryTest do
  use Chat.DataCase, async: true

  alias Chat.Infrastructure.Repositories.SessionRepository
  alias Chat.Infrastructure.Schemas.{MessageSchema, SessionSchema}

  describe "session repository" do
    test "create_session/1 and get_session_by_id/1" do
      user_id = Ecto.UUID.generate()
      assert {:ok, session} = SessionRepository.create_session(%{user_id: user_id, title: "Test"})

      assert found = SessionRepository.get_session_by_id(session.id)
      assert found.id == session.id
      assert Ecto.assoc_loaded?(found.messages)
    end

    test "get_session_by_id/2 with pagination opts limits messages" do
      user_id = Ecto.UUID.generate()
      {:ok, session} = SessionRepository.create_session(%{user_id: user_id, title: "Paginated"})

      for i <- 1..5 do
        insert_message(%{chat_session_id: session.id, content: "msg #{i}"})
      end

      found = SessionRepository.get_session_by_id(session.id, message_limit: 3)
      assert found.id == session.id
      assert length(found.messages) == 3
    end

    test "list_user_sessions/2 and get_first_message_content/1" do
      user_id = Ecto.UUID.generate()
      s1 = insert_session(%{user_id: user_id})
      s2 = insert_session(%{user_id: user_id})
      _ = insert_message(%{chat_session_id: s2.id, content: "First"})
      _ = insert_message(%{chat_session_id: s2.id, content: "Second"})

      sessions = SessionRepository.list_user_sessions(user_id, 10)
      assert Enum.any?(sessions, &(&1.id == s1.id))
      assert Enum.any?(sessions, &(&1.id == s2.id))
      assert SessionRepository.get_first_message_content(s2.id) == "First"
    end

    test "list_user_sessions_with_preview/2 returns batch previews" do
      user_id = Ecto.UUID.generate()
      s1 = insert_session(%{user_id: user_id})
      s2 = insert_session(%{user_id: user_id})
      _ = insert_message(%{chat_session_id: s1.id, content: "Preview for s1"})
      _ = insert_message(%{chat_session_id: s2.id, content: "Preview for s2"})

      sessions = SessionRepository.list_user_sessions_with_preview(user_id, 10)
      by_id = Map.new(sessions, &{&1.id, &1})
      assert by_id[s1.id].preview == "Preview for s1"
      assert by_id[s2.id].preview == "Preview for s2"
    end

    test "load_messages/2 returns messages before cursor" do
      session = insert_session()
      m1 = insert_message(%{chat_session_id: session.id, content: "First"})
      _m2 = insert_message(%{chat_session_id: session.id, content: "Second"})
      m3 = insert_message(%{chat_session_id: session.id, content: "Third"})

      messages =
        SessionRepository.load_messages(session.id, message_limit: 50, before_id: m3.id)

      result_ids = Enum.map(messages, & &1.id)
      refute m3.id in result_ids
      assert m1.id in result_ids
    end

    test "get_session_by_id_and_user/2 and get_message_by_id_and_user/2" do
      user_id = Ecto.UUID.generate()
      session = insert_session(%{user_id: user_id})
      message = insert_message(%{chat_session_id: session.id})

      assert SessionRepository.get_session_by_id_and_user(session.id, user_id)
      assert nil == SessionRepository.get_session_by_id_and_user(session.id, Ecto.UUID.generate())

      assert SessionRepository.get_message_by_id_and_user(message.id, user_id)
      assert nil == SessionRepository.get_message_by_id_and_user(message.id, Ecto.UUID.generate())
    end

    test "delete_session/1 removes session" do
      session = insert_session()
      assert {:ok, _deleted} = SessionRepository.delete_session(session)
      assert nil == Repo.get(SessionSchema, session.id)
    end
  end

  defp insert_session(attrs \\ %{}) do
    base = %{user_id: Ecto.UUID.generate(), title: "Session"}

    %SessionSchema{}
    |> SessionSchema.changeset(Map.merge(base, attrs))
    |> Repo.insert!()
  end

  defp insert_message(attrs) do
    session_id = Map.get(attrs, :chat_session_id) || insert_session().id
    base = %{chat_session_id: session_id, role: "user", content: "hello", context_chunks: []}

    %MessageSchema{}
    |> MessageSchema.changeset(Map.merge(base, attrs))
    |> Repo.insert!()
  end
end
