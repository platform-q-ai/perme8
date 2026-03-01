defmodule Chat.Application.UseCases.ListSessionsTest do
  use ExUnit.Case, async: true

  import Mox

  alias Chat.Application.UseCases.ListSessions
  alias Chat.Mocks.SessionRepositoryMock

  setup :verify_on_exit!

  test "lists sessions for user and applies limit" do
    user_id = Ecto.UUID.generate()
    s1 = %{id: Ecto.UUID.generate(), title: "A", message_count: 1}
    s2 = %{id: Ecto.UUID.generate(), title: "B", message_count: 2}
    s1_id = s1.id
    s2_id = s2.id

    SessionRepositoryMock
    |> expect(:list_user_sessions, fn ^user_id, 2 -> [s1, s2] end)
    |> expect(:get_first_message_content, fn ^s1_id -> "preview one" end)
    |> expect(:get_first_message_content, fn ^s2_id -> "preview two" end)

    assert {:ok, sessions} =
             ListSessions.execute(user_id, limit: 2, session_repository: SessionRepositoryMock)

    assert Enum.map(sessions, & &1.preview) == ["preview one", "preview two"]
  end

  test "truncates long preview content" do
    user_id = Ecto.UUID.generate()
    session = %{id: Ecto.UUID.generate(), title: "A", message_count: 1}
    session_id = session.id
    long = String.duplicate("a", 120)

    SessionRepositoryMock
    |> expect(:list_user_sessions, fn ^user_id, 50 -> [session] end)
    |> expect(:get_first_message_content, fn ^session_id -> long end)

    assert {:ok, [result]} =
             ListSessions.execute(user_id, session_repository: SessionRepositoryMock)

    assert String.length(result.preview) <= 103
    assert String.ends_with?(result.preview, "...")
  end
end
