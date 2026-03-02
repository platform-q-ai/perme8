defmodule Chat.Application.UseCases.ListSessionsTest do
  use ExUnit.Case, async: true

  import Mox

  alias Chat.Application.UseCases.ListSessions
  alias Chat.Mocks.SessionRepositoryMock

  setup :verify_on_exit!

  test "lists sessions using batched preview query (no N+1)" do
    user_id = Ecto.UUID.generate()

    s1 = %{id: Ecto.UUID.generate(), title: "A", message_count: 1, preview: "preview one"}
    s2 = %{id: Ecto.UUID.generate(), title: "B", message_count: 2, preview: "preview two"}

    SessionRepositoryMock
    |> expect(:list_user_sessions_with_preview, fn ^user_id, 2 -> [s1, s2] end)

    assert {:ok, sessions} =
             ListSessions.execute(user_id, limit: 2, session_repository: SessionRepositoryMock)

    assert Enum.map(sessions, & &1.preview) == ["preview one", "preview two"]
  end

  test "truncates long preview content" do
    user_id = Ecto.UUID.generate()
    long = String.duplicate("a", 120)
    session = %{id: Ecto.UUID.generate(), title: "A", message_count: 1, preview: long}

    SessionRepositoryMock
    |> expect(:list_user_sessions_with_preview, fn ^user_id, 50 -> [session] end)

    assert {:ok, [result]} =
             ListSessions.execute(user_id, session_repository: SessionRepositoryMock)

    assert String.length(result.preview) <= 103
    assert String.ends_with?(result.preview, "...")
  end

  test "handles nil preview gracefully" do
    user_id = Ecto.UUID.generate()
    session = %{id: Ecto.UUID.generate(), title: "Empty", message_count: 0, preview: nil}

    SessionRepositoryMock
    |> expect(:list_user_sessions_with_preview, fn ^user_id, 50 -> [session] end)

    assert {:ok, [result]} =
             ListSessions.execute(user_id, session_repository: SessionRepositoryMock)

    assert result.preview == nil
  end
end
