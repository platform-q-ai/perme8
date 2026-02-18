defmodule Jarga.Chat.Application.UseCases.DeleteSessionTest do
  @moduledoc """
  Tests for DeleteSession use case.
  """
  use Jarga.DataCase, async: false

  import Jarga.AccountsFixtures
  import Jarga.ChatFixtures

  alias Jarga.Chat.Application.UseCases.DeleteSession
  alias Jarga.Chat.Domain.Events.ChatSessionDeleted
  # Use Identity.Repo for all operations to ensure consistent transaction visibility
  alias Identity.Repo, as: Repo

  describe "execute/3 - event emission" do
    test "emits ChatSessionDeleted event via event_bus" do
      ensure_test_event_bus_started()

      user = user_fixture()
      session = chat_session_fixture(user: user)

      assert {:ok, deleted_session} =
               DeleteSession.execute(session.id, user.id, event_bus: Perme8.Events.TestEventBus)

      assert [%ChatSessionDeleted{} = event] = Perme8.Events.TestEventBus.get_events()
      assert event.session_id == deleted_session.id
      assert event.user_id == user.id
      assert event.aggregate_id == deleted_session.id
      assert event.actor_id == user.id
    end

    test "does not emit event when session not found" do
      ensure_test_event_bus_started()

      user = user_fixture()
      fake_id = Ecto.UUID.generate()

      assert {:error, :not_found} =
               DeleteSession.execute(fake_id, user.id, event_bus: Perme8.Events.TestEventBus)

      assert [] = Perme8.Events.TestEventBus.get_events()
    end
  end

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
      assert Repo.get(Jarga.Chat.Infrastructure.Schemas.SessionSchema, session.id) == nil

      # Messages should be deleted (cascade)
      assert Repo.get(Jarga.Chat.Infrastructure.Schemas.MessageSchema, msg1.id) == nil
      assert Repo.get(Jarga.Chat.Infrastructure.Schemas.MessageSchema, msg2.id) == nil
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
      assert Repo.get(Jarga.Chat.Infrastructure.Schemas.SessionSchema, session.id) != nil
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
      assert Repo.get(Jarga.Chat.Infrastructure.Schemas.SessionSchema, session1.id) == nil
      assert Repo.get(Jarga.Chat.Infrastructure.Schemas.MessageSchema, msg1.id) == nil

      # Session2 and its message should still exist
      assert Repo.get(Jarga.Chat.Infrastructure.Schemas.SessionSchema, session2.id) != nil
      assert Repo.get(Jarga.Chat.Infrastructure.Schemas.MessageSchema, msg2.id) != nil
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
