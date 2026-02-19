defmodule Jarga.Projects.Domain.Events.ProjectArchivedTest do
  use ExUnit.Case, async: true

  alias Jarga.Projects.Domain.Events.ProjectArchived

  @valid_attrs %{
    aggregate_id: "proj-123",
    actor_id: "user-123",
    project_id: "proj-123",
    workspace_id: "ws-123",
    user_id: "user-123"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert ProjectArchived.event_type() == "projects.project_archived"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert ProjectArchived.aggregate_type() == "project"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = ProjectArchived.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "projects.project_archived"
      assert event.aggregate_type == "project"
      assert event.project_id == "proj-123"
      assert event.workspace_id == "ws-123"
      assert event.user_id == "user-123"
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        ProjectArchived.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
