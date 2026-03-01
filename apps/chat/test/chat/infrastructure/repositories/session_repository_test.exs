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
