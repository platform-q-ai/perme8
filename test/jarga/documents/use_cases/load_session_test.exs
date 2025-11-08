defmodule Jarga.Documents.UseCases.LoadSessionTest do
  @moduledoc """
  Tests for LoadSession use case.
  """
  use Jarga.DataCase, async: true

  import Jarga.DocumentsFixtures

  alias Jarga.Documents.UseCases.LoadSession

  describe "execute/1" do
    test "loads a session with its messages" do
      session = chat_session_fixture()

      # Add some messages to the session
      _msg1 = chat_message_fixture(chat_session: session, role: "user", content: "Hello")
      _msg2 = chat_message_fixture(chat_session: session, role: "assistant", content: "Hi there!")
      _msg3 = chat_message_fixture(chat_session: session, role: "user", content: "How are you?")

      assert {:ok, loaded_session} = LoadSession.execute(session.id)

      assert loaded_session.id == session.id
      assert length(loaded_session.messages) == 3

      # Messages should be ordered by insertion time (oldest first)
      assert Enum.map(loaded_session.messages, & &1.content) == [
               "Hello",
               "Hi there!",
               "How are you?"
             ]
    end

    test "loads a session without messages" do
      session = chat_session_fixture()

      assert {:ok, loaded_session} = LoadSession.execute(session.id)

      assert loaded_session.id == session.id
      assert loaded_session.messages == []
    end

    test "returns error when session does not exist" do
      fake_id = Ecto.UUID.generate()

      assert {:error, :not_found} = LoadSession.execute(fake_id)
    end

    test "preloads session relationships" do
      session = chat_session_fixture()

      assert {:ok, loaded_session} = LoadSession.execute(session.id)

      # User should be preloaded
      assert loaded_session.user != nil
      refute Ecto.assoc_loaded?(loaded_session.user) == false

      # Workspace should be preloaded if it exists
      if session.workspace_id do
        assert loaded_session.workspace != nil
        refute Ecto.assoc_loaded?(loaded_session.workspace) == false
      end
    end

    test "messages include all required fields" do
      session = chat_session_fixture()
      chunk_ids = [Ecto.UUID.generate(), Ecto.UUID.generate()]

      _msg =
        chat_message_fixture(
          chat_session: session,
          role: "assistant",
          content: "Based on documents...",
          context_chunks: chunk_ids
        )

      assert {:ok, loaded_session} = LoadSession.execute(session.id)

      [message] = loaded_session.messages
      assert message.role == "assistant"
      assert message.content == "Based on documents..."
      assert message.context_chunks == chunk_ids
      assert message.inserted_at != nil
    end

    test "only loads messages for the specific session" do
      session1 = chat_session_fixture()
      session2 = chat_session_fixture()

      chat_message_fixture(chat_session: session1, content: "Session 1 message")
      chat_message_fixture(chat_session: session2, content: "Session 2 message")

      assert {:ok, loaded_session1} = LoadSession.execute(session1.id)
      assert {:ok, loaded_session2} = LoadSession.execute(session2.id)

      assert length(loaded_session1.messages) == 1
      assert length(loaded_session2.messages) == 1

      assert List.first(loaded_session1.messages).content == "Session 1 message"
      assert List.first(loaded_session2.messages).content == "Session 2 message"
    end
  end
end
