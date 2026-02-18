defmodule Jarga.Chat.Application.UseCases.SaveMessageTest do
  @moduledoc """
  Tests for SaveMessage use case.
  """
  use Jarga.DataCase, async: false

  import Jarga.ChatFixtures

  alias Jarga.Chat.Application.UseCases.SaveMessage
  alias Jarga.Chat.Domain.Events.ChatMessageSent
  alias Jarga.Chat.Infrastructure.Schemas.MessageSchema
  # Use Identity.Repo for all operations to ensure consistent transaction visibility
  alias Identity.Repo, as: Repo

  describe "execute/2 - event emission" do
    test "emits ChatMessageSent event via event_bus" do
      ensure_test_event_bus_started()

      session = chat_session_fixture()

      assert {:ok, message} =
               SaveMessage.execute(
                 %{
                   chat_session_id: session.id,
                   role: "user",
                   content: "Hello from event test"
                 },
                 event_bus: Perme8.Events.TestEventBus
               )

      assert [%ChatMessageSent{} = event] = Perme8.Events.TestEventBus.get_events()
      assert event.message_id == message.id
      assert event.session_id == session.id
      assert event.user_id == session.user_id
      assert event.role == "user"
      assert event.aggregate_id == message.id
      assert event.actor_id == session.user_id
    end

    test "does not emit event when message creation fails" do
      ensure_test_event_bus_started()

      assert {:error, _changeset} =
               SaveMessage.execute(
                 %{role: "user", content: "No session"},
                 event_bus: Perme8.Events.TestEventBus
               )

      assert [] = Perme8.Events.TestEventBus.get_events()
    end
  end

  describe "execute/1" do
    test "saves a user message" do
      session = chat_session_fixture()

      assert {:ok, message} =
               SaveMessage.execute(%{
                 chat_session_id: session.id,
                 role: "user",
                 content: "What is the project status?"
               })

      assert message.chat_session_id == session.id
      assert message.role == "user"
      assert message.content == "What is the project status?"
      assert message.context_chunks == []

      # Verify it was persisted
      persisted = Repo.get(MessageSchema, message.id)
      assert persisted.id == message.id
    end

    test "saves an assistant message" do
      session = chat_session_fixture()

      assert {:ok, message} =
               SaveMessage.execute(%{
                 chat_session_id: session.id,
                 role: "assistant",
                 content: "The project is on track."
               })

      assert message.role == "assistant"
      assert message.content == "The project is on track."
    end

    test "saves message with context_chunks" do
      session = chat_session_fixture()
      chunk_ids = [Ecto.UUID.generate(), Ecto.UUID.generate()]

      assert {:ok, message} =
               SaveMessage.execute(%{
                 chat_session_id: session.id,
                 role: "assistant",
                 content: "Based on the documents...",
                 context_chunks: chunk_ids
               })

      assert message.context_chunks == chunk_ids
    end

    test "returns error when chat_session_id is missing" do
      assert {:error, changeset} =
               SaveMessage.execute(%{
                 role: "user",
                 content: "Hello"
               })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).chat_session_id
    end

    test "returns error when role is missing" do
      session = chat_session_fixture()

      assert {:error, changeset} =
               SaveMessage.execute(%{
                 chat_session_id: session.id,
                 content: "Hello"
               })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).role
    end

    test "returns error when content is missing" do
      session = chat_session_fixture()

      assert {:error, changeset} =
               SaveMessage.execute(%{
                 chat_session_id: session.id,
                 role: "user"
               })

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).content
    end

    test "returns error with invalid role" do
      session = chat_session_fixture()

      assert {:error, changeset} =
               SaveMessage.execute(%{
                 chat_session_id: session.id,
                 role: "system",
                 content: "Hello"
               })

      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).role
    end

    test "trims whitespace from content" do
      session = chat_session_fixture()

      assert {:ok, message} =
               SaveMessage.execute(%{
                 chat_session_id: session.id,
                 role: "user",
                 content: "  Hello World  "
               })

      assert message.content == "Hello World"
    end

    test "saves messages in order for a session" do
      session = chat_session_fixture()

      {:ok, msg1} =
        SaveMessage.execute(%{
          chat_session_id: session.id,
          role: "user",
          content: "First message"
        })

      {:ok, msg2} =
        SaveMessage.execute(%{
          chat_session_id: session.id,
          role: "assistant",
          content: "Second message"
        })

      {:ok, msg3} =
        SaveMessage.execute(%{
          chat_session_id: session.id,
          role: "user",
          content: "Third message"
        })

      # Verify insertion order (should be chronological or equal, never reverse)
      refute DateTime.compare(msg1.inserted_at, msg2.inserted_at) == :gt
      refute DateTime.compare(msg2.inserted_at, msg3.inserted_at) == :gt

      # All three messages should exist for the session
      messages =
        Repo.all(
          from(m in MessageSchema,
            where: m.chat_session_id == ^session.id,
            order_by: [asc: m.inserted_at]
          )
        )

      assert length(messages) == 3

      assert Enum.map(messages, & &1.content) == [
               "First message",
               "Second message",
               "Third message"
             ]
    end
  end

  defp ensure_test_event_bus_started do
    case Process.whereis(Perme8.Events.TestEventBus) do
      nil ->
        {:ok, _pid} = Perme8.Events.TestEventBus.start_link([])
        :ok

      _pid ->
        Perme8.Events.TestEventBus.reset()
    end
  end
end
