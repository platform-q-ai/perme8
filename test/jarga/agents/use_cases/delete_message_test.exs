defmodule Jarga.Agents.UseCases.DeleteMessageTest do
  @moduledoc """
  Tests for DeleteMessage use case.
  """
  use Jarga.DataCase, async: true

  import Jarga.AgentsFixtures

  alias Jarga.Agents.UseCases.DeleteMessage
  alias Jarga.Agents.UseCases.SaveMessage
  alias Jarga.Agents.ChatMessage
  alias Jarga.Repo

  describe "execute/2" do
    test "deletes a message owned by the user" do
      session = chat_session_fixture()

      {:ok, message} =
        SaveMessage.execute(%{
          chat_session_id: session.id,
          role: "user",
          content: "Test message"
        })

      assert {:ok, deleted} = DeleteMessage.execute(message.id, session.user_id)
      assert deleted.id == message.id

      # Verify it was deleted
      assert Repo.get(ChatMessage, message.id) == nil
    end

    test "returns error when message does not exist" do
      user = Jarga.AccountsFixtures.user_fixture()
      fake_id = Ecto.UUID.generate()

      assert {:error, :not_found} = DeleteMessage.execute(fake_id, user.id)
    end

    test "returns error when user does not own the session" do
      session = chat_session_fixture()
      other_user = Jarga.AccountsFixtures.user_fixture()

      {:ok, message} =
        SaveMessage.execute(%{
          chat_session_id: session.id,
          role: "user",
          content: "Test message"
        })

      assert {:error, :not_found} = DeleteMessage.execute(message.id, other_user.id)

      # Verify message still exists
      assert Repo.get(ChatMessage, message.id) != nil
    end

    test "deletes assistant message" do
      session = chat_session_fixture()

      {:ok, message} =
        SaveMessage.execute(%{
          chat_session_id: session.id,
          role: "assistant",
          content: "Assistant response"
        })

      assert {:ok, _} = DeleteMessage.execute(message.id, session.user_id)
      assert Repo.get(ChatMessage, message.id) == nil
    end
  end
end
