defmodule Chat.Application.UseCases.LoadSessionTest do
  use ExUnit.Case, async: true

  import Mox

  alias Chat.Application.UseCases.LoadSession
  alias Chat.Mocks.SessionRepositoryMock

  setup :verify_on_exit!

  test "loads session with default pagination (50 messages)" do
    session_id = Ecto.UUID.generate()
    session = %{id: session_id, messages: []}

    SessionRepositoryMock
    |> expect(:get_session_by_id, fn ^session_id, [message_limit: 50] -> session end)

    assert {:ok, ^session} =
             LoadSession.execute(session_id, session_repository: SessionRepositoryMock)
  end

  test "loads session with custom message_limit" do
    session_id = Ecto.UUID.generate()
    session = %{id: session_id, messages: []}

    SessionRepositoryMock
    |> expect(:get_session_by_id, fn ^session_id, [message_limit: 20] -> session end)

    assert {:ok, ^session} =
             LoadSession.execute(session_id,
               session_repository: SessionRepositoryMock,
               message_limit: 20
             )
  end

  test "returns :not_found for missing session" do
    session_id = Ecto.UUID.generate()

    SessionRepositoryMock
    |> expect(:get_session_by_id, fn ^session_id, [message_limit: 50] -> nil end)

    assert {:error, :not_found} =
             LoadSession.execute(session_id, session_repository: SessionRepositoryMock)
  end

  describe "load_older_messages/3" do
    test "returns messages and has_more? true when more exist" do
      session_id = Ecto.UUID.generate()
      before_id = Ecto.UUID.generate()

      # Return 51 messages (limit + 1) to indicate more exist
      messages = for i <- 1..51, do: %{id: Ecto.UUID.generate(), content: "msg #{i}"}

      SessionRepositoryMock
      |> expect(:load_messages, fn ^session_id, [message_limit: 51, before_id: ^before_id] ->
        messages
      end)

      assert {:ok, returned, true} =
               LoadSession.load_older_messages(session_id, before_id,
                 session_repository: SessionRepositoryMock
               )

      assert length(returned) == 50
    end

    test "returns messages and has_more? false when no more exist" do
      session_id = Ecto.UUID.generate()
      before_id = Ecto.UUID.generate()

      messages = for i <- 1..10, do: %{id: Ecto.UUID.generate(), content: "msg #{i}"}

      SessionRepositoryMock
      |> expect(:load_messages, fn ^session_id, [message_limit: 51, before_id: ^before_id] ->
        messages
      end)

      assert {:ok, returned, false} =
               LoadSession.load_older_messages(session_id, before_id,
                 session_repository: SessionRepositoryMock
               )

      assert length(returned) == 10
    end

    test "supports custom message_limit" do
      session_id = Ecto.UUID.generate()
      before_id = Ecto.UUID.generate()
      messages = for i <- 1..5, do: %{id: Ecto.UUID.generate(), content: "msg #{i}"}

      SessionRepositoryMock
      |> expect(:load_messages, fn ^session_id, [message_limit: 11, before_id: ^before_id] ->
        messages
      end)

      assert {:ok, returned, false} =
               LoadSession.load_older_messages(session_id, before_id,
                 session_repository: SessionRepositoryMock,
                 message_limit: 10
               )

      assert length(returned) == 5
    end
  end
end
