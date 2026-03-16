defmodule Agents.Sessions.Domain.Events.SessionPausedTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.SessionPaused

  test "new/1 creates a valid session paused event" do
    event =
      SessionPaused.new(%{
        aggregate_id: "session-1",
        actor_id: "user-1",
        session_id: "session-1",
        user_id: "user-1",
        paused_at: ~U[2026-03-16 14:00:00Z]
      })

    assert event.session_id == "session-1"
    assert event.user_id == "user-1"
    assert event.paused_at == ~U[2026-03-16 14:00:00Z]
    assert event.aggregate_id == "session-1"
    assert event.aggregate_type == "session"
  end
end
