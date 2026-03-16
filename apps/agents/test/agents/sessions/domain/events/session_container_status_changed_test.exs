defmodule Agents.Sessions.Domain.Events.SessionContainerStatusChangedTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.SessionContainerStatusChanged

  test "new/1 creates a valid container status changed event" do
    event =
      SessionContainerStatusChanged.new(%{
        aggregate_id: "session-1",
        actor_id: "user-1",
        session_id: "session-1",
        user_id: "user-1",
        from_status: "pending",
        to_status: "running",
        container_id: "abc123"
      })

    assert event.session_id == "session-1"
    assert event.from_status == "pending"
    assert event.to_status == "running"
    assert event.container_id == "abc123"
    assert event.aggregate_type == "session"
  end
end
