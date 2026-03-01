defmodule Chat.Application.UseCases.DeleteSessionTest do
  use ExUnit.Case, async: true

  import Mox

  alias Chat.Application.UseCases.DeleteSession
  alias Chat.Domain.Events.ChatSessionDeleted
  alias Chat.Mocks.SessionRepositoryMock
  alias Perme8.Events.TestEventBus

  setup :verify_on_exit!

  setup do
    bus_name = :"chat_delete_session_bus_#{System.unique_integer([:positive])}"
    {:ok, _pid} = TestEventBus.start_link(name: bus_name)
    %{bus_name: bus_name}
  end

  test "deletes session when user owns it and emits event", %{bus_name: bus_name} do
    session_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()

    session = %{id: session_id, user_id: user_id, workspace_id: nil}

    SessionRepositoryMock
    |> expect(:get_session_by_id_and_user, fn ^session_id, ^user_id -> session end)
    |> expect(:delete_session, fn ^session -> {:ok, session} end)

    assert {:ok, ^session} =
             DeleteSession.execute(session_id, user_id,
               session_repository: SessionRepositoryMock,
               event_bus: TestEventBus,
               event_bus_opts: [name: bus_name]
             )

    assert [%ChatSessionDeleted{} = event] = TestEventBus.get_events(name: bus_name)
    assert event.session_id == session_id
    assert event.user_id == user_id
  end

  test "returns :not_found for missing or unauthorized session", %{bus_name: bus_name} do
    session_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()

    SessionRepositoryMock
    |> expect(:get_session_by_id_and_user, fn ^session_id, ^user_id -> nil end)

    assert {:error, :not_found} =
             DeleteSession.execute(session_id, user_id,
               session_repository: SessionRepositoryMock,
               event_bus: TestEventBus,
               event_bus_opts: [name: bus_name]
             )

    assert [] = TestEventBus.get_events(name: bus_name)
  end
end
