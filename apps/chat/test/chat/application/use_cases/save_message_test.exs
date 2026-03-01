defmodule Chat.Application.UseCases.SaveMessageTest do
  use ExUnit.Case, async: true

  import Mox

  alias Chat.Application.UseCases.SaveMessage
  alias Chat.Domain.Events.ChatMessageSent
  alias Chat.Mocks.MessageRepositoryMock
  alias Chat.Mocks.SessionRepositoryMock
  alias Perme8.Events.TestEventBus

  setup :verify_on_exit!

  setup do
    bus_name = :"chat_save_message_bus_#{System.unique_integer([:positive])}"
    {:ok, _pid} = TestEventBus.start_link(name: bus_name)
    %{bus_name: bus_name}
  end

  test "saves message with valid attrs and emits event", %{bus_name: bus_name} do
    session_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()
    message_id = Ecto.UUID.generate()

    message = %{id: message_id, chat_session_id: session_id, role: "user", content: "Hello"}

    MessageRepositoryMock
    |> expect(:create_message, fn attrs ->
      assert attrs.chat_session_id == session_id
      {:ok, message}
    end)

    SessionRepositoryMock
    |> expect(:get_session_by_id, fn ^session_id ->
      %{id: session_id, user_id: user_id, workspace_id: nil}
    end)

    assert {:ok, ^message} =
             SaveMessage.execute(%{chat_session_id: session_id, role: "user", content: "Hello"},
               message_repository: MessageRepositoryMock,
               session_repository: SessionRepositoryMock,
               event_bus: TestEventBus,
               event_bus_opts: [name: bus_name]
             )

    assert [%ChatMessageSent{} = event] = TestEventBus.get_events(name: bus_name)
    assert event.message_id == message_id
    assert event.session_id == session_id
    assert event.user_id == user_id
    assert event.role == "user"
  end

  test "returns error on invalid attrs and does not emit event", %{bus_name: bus_name} do
    changeset = %Ecto.Changeset{valid?: false, errors: [content: {"can't be blank", []}]}

    MessageRepositoryMock
    |> expect(:create_message, fn _attrs ->
      {:error, changeset}
    end)

    assert {:error, ^changeset} =
             SaveMessage.execute(%{chat_session_id: Ecto.UUID.generate()},
               message_repository: MessageRepositoryMock,
               session_repository: SessionRepositoryMock,
               event_bus: TestEventBus,
               event_bus_opts: [name: bus_name]
             )

    assert [] = TestEventBus.get_events(name: bus_name)
  end
end
