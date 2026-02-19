defmodule Jarga.Projects.Domain.Events.ProjectUpdatedTest do
  use ExUnit.Case, async: true

  alias Jarga.Projects.Domain.Events.ProjectUpdated

  @valid_attrs %{
    aggregate_id: "proj-123",
    actor_id: "user-123",
    project_id: "proj-123",
    workspace_id: "ws-123",
    user_id: "user-123"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert ProjectUpdated.event_type() == "projects.project_updated"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert ProjectUpdated.aggregate_type() == "project"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = ProjectUpdated.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "projects.project_updated"
      assert event.aggregate_type == "project"
      assert event.project_id == "proj-123"
      assert event.workspace_id == "ws-123"
      assert event.user_id == "user-123"
    end

    test "optional name defaults to nil" do
      event = ProjectUpdated.new(@valid_attrs)
      assert event.name == nil
    end

    test "optional changes defaults to empty map" do
      event = ProjectUpdated.new(@valid_attrs)
      assert event.changes == %{}
    end

    test "accepts optional fields" do
      event =
        ProjectUpdated.new(
          Map.merge(@valid_attrs, %{name: "New Name", changes: %{name: "New Name"}})
        )

      assert event.name == "New Name"
      assert event.changes == %{name: "New Name"}
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        ProjectUpdated.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
