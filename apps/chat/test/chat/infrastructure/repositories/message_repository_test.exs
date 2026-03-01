defmodule Chat.Infrastructure.Repositories.MessageRepositoryTest do
  use Chat.DataCase, async: true

  alias Chat.Infrastructure.Repositories.MessageRepository
  alias Chat.Infrastructure.Schemas.{MessageSchema, SessionSchema}

  describe "message repository" do
    test "get/1 returns message by id" do
      message = insert_message()
      assert found = MessageRepository.get(message.id)
      assert found.id == message.id
    end

    test "create_message/1 persists message" do
      session = insert_session()

      assert {:ok, message} =
               MessageRepository.create_message(%{
                 chat_session_id: session.id,
                 role: "assistant",
                 content: "Reply"
               })

      assert message.chat_session_id == session.id
      assert message.role == "assistant"
      assert message.content == "Reply"
    end

    test "delete_message/1 removes persisted message" do
      message = insert_message()
      assert {:ok, _} = MessageRepository.delete_message(message)
      assert nil == Repo.get(MessageSchema, message.id)
    end
  end

  defp insert_session(attrs \\ %{}) do
    base = %{user_id: Ecto.UUID.generate(), title: "Session"}

    %SessionSchema{}
    |> SessionSchema.changeset(Map.merge(base, attrs))
    |> Repo.insert!()
  end

  defp insert_message(attrs \\ %{}) do
    session_id = Map.get(attrs, :chat_session_id) || insert_session().id
    base = %{chat_session_id: session_id, role: "user", content: "hello", context_chunks: []}

    %MessageSchema{}
    |> MessageSchema.changeset(Map.merge(base, attrs))
    |> Repo.insert!()
  end
end
