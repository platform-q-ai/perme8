defmodule Agents.Sessions.Domain.Events.SessionWarmedTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.SessionWarmed

  @valid_attrs %{
    aggregate_id: "session-123",
    actor_id: "user-123",
    task_id: "task-123",
    user_id: "user-123",
    container_id: "container-123",
    container_port: 4100
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert SessionWarmed.event_type() == "sessions.session_warmed"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert SessionWarmed.aggregate_type() == "session"
    end
  end

  describe "new/1" do
    test "creates event with valid attrs" do
      event = SessionWarmed.new(@valid_attrs)

      assert event.task_id == "task-123"
      assert event.container_id == "container-123"
      assert event.container_port == 4100
      assert event.event_type == "sessions.session_warmed"
      assert event.aggregate_type == "session"
    end

    test "auto-generates event_id and occurred_at" do
      event = SessionWarmed.new(@valid_attrs)

      assert is_binary(event.event_id)
      assert %DateTime{} = event.occurred_at
    end
  end
end
