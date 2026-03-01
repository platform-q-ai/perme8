defmodule Chat.Application.UseCases.DeleteMessageTest do
  use ExUnit.Case, async: true

  import Mox

  alias Chat.Application.UseCases.DeleteMessage
  alias Chat.Mocks.MessageRepositoryMock
  alias Chat.Mocks.SessionRepositoryMock

  setup :verify_on_exit!

  test "deletes message when user owns session" do
    message_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()
    message = %{id: message_id}

    SessionRepositoryMock
    |> expect(:get_message_by_id_and_user, fn ^message_id, ^user_id -> message end)

    MessageRepositoryMock
    |> expect(:delete_message, fn ^message -> {:ok, message} end)

    assert {:ok, ^message} =
             DeleteMessage.execute(message_id, user_id,
               session_repository: SessionRepositoryMock,
               message_repository: MessageRepositoryMock
             )
  end

  test "returns :not_found for missing or unauthorized message" do
    message_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()

    SessionRepositoryMock
    |> expect(:get_message_by_id_and_user, fn ^message_id, ^user_id -> nil end)

    assert {:error, :not_found} =
             DeleteMessage.execute(message_id, user_id,
               session_repository: SessionRepositoryMock,
               message_repository: MessageRepositoryMock
             )
  end
end
