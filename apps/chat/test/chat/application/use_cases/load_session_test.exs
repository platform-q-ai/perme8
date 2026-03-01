defmodule Chat.Application.UseCases.LoadSessionTest do
  use ExUnit.Case, async: true

  import Mox

  alias Chat.Application.UseCases.LoadSession
  alias Chat.Mocks.SessionRepositoryMock

  setup :verify_on_exit!

  test "loads session by ID" do
    session_id = Ecto.UUID.generate()
    session = %{id: session_id, messages: []}

    SessionRepositoryMock
    |> expect(:get_session_by_id, fn ^session_id -> session end)

    assert {:ok, ^session} =
             LoadSession.execute(session_id, session_repository: SessionRepositoryMock)
  end

  test "returns :not_found for missing session" do
    session_id = Ecto.UUID.generate()

    SessionRepositoryMock
    |> expect(:get_session_by_id, fn ^session_id -> nil end)

    assert {:error, :not_found} =
             LoadSession.execute(session_id, session_repository: SessionRepositoryMock)
  end
end
