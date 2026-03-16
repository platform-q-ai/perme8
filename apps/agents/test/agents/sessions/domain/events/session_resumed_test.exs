defmodule Agents.Sessions.Domain.Events.SessionResumedTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.SessionResumed

  test "new/1 creates a valid session resumed event" do
    event =
      SessionResumed.new(%{
        aggregate_id: "session-1",
        actor_id: "user-1",
        session_id: "session-1",
        user_id: "user-1",
        resumed_at: ~U[2026-03-16 14:00:00Z]
      })

    assert event.session_id == "session-1"
    assert event.user_id == "user-1"
    assert event.resumed_at == ~U[2026-03-16 14:00:00Z]
    assert event.aggregate_id == "session-1"
    assert event.aggregate_type == "session"
  end
end
