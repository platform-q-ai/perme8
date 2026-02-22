defmodule Jarga.Webhooks.Domain.Policies.EventFilterPolicyTest do
  use ExUnit.Case, async: true

  alias Jarga.Webhooks.Domain.Policies.EventFilterPolicy

  describe "matches?/2" do
    test "matches when event_type is in subscription's event_types" do
      subscription = %{event_types: ["projects.project_created", "projects.project_updated"]}

      assert EventFilterPolicy.matches?("projects.project_created", subscription) == true
    end

    test "returns false when event_type not in subscription's event_types" do
      subscription = %{event_types: ["projects.project_created"]}

      assert EventFilterPolicy.matches?("projects.project_deleted", subscription) == false
    end

    test "empty event_types list matches ALL events (wildcard)" do
      subscription = %{event_types: []}

      assert EventFilterPolicy.matches?("any.event", subscription) == true
    end

    test "nil event_types matches ALL events (wildcard)" do
      subscription = %{event_types: nil}

      assert EventFilterPolicy.matches?("any.event", subscription) == true
    end
  end

  describe "valid_event_types?/1" do
    test "validates list of correctly formatted event type strings" do
      assert EventFilterPolicy.valid_event_types?(["projects.project_created"]) == true
    end

    test "validates multiple event types" do
      types = ["projects.project_created", "webhooks.delivery_completed"]
      assert EventFilterPolicy.valid_event_types?(types) == true
    end

    test "returns true for empty list (wildcard)" do
      assert EventFilterPolicy.valid_event_types?([]) == true
    end

    test "returns false for invalid format (no dot separator)" do
      assert EventFilterPolicy.valid_event_types?(["invalid"]) == false
    end

    test "returns false for event type with only dots" do
      assert EventFilterPolicy.valid_event_types?(["."]) == false
    end

    test "returns false when any event type in list is invalid" do
      assert EventFilterPolicy.valid_event_types?(["valid.type", "invalid"]) == false
    end
  end
end
