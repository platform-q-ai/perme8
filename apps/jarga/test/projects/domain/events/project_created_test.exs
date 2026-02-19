defmodule Jarga.Projects.Domain.Events.ProjectCreatedTest do
  use ExUnit.Case, async: true

  alias Jarga.Projects.Domain.Events.ProjectCreated

  @valid_attrs %{
    aggregate_id: "proj-123",
    actor_id: "user-123",
    project_id: "proj-123",
    workspace_id: "ws-123",
    user_id: "user-123",
    name: "Test Project",
    slug: "test-project"
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert ProjectCreated.event_type() == "projects.project_created"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert ProjectCreated.aggregate_type() == "project"
    end
  end

  describe "new/1" do
    test "creates event with auto-generated fields" do
      event = ProjectCreated.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "projects.project_created"
      assert event.aggregate_type == "project"
      assert event.aggregate_id == "proj-123"
      assert event.actor_id == "user-123"
      assert event.project_id == "proj-123"
      assert event.workspace_id == "ws-123"
      assert event.user_id == "user-123"
      assert event.name == "Test Project"
      assert event.slug == "test-project"
      assert event.metadata == %{}
    end

    test "generates unique event_id for each call" do
      event1 = ProjectCreated.new(@valid_attrs)
      event2 = ProjectCreated.new(@valid_attrs)

      assert event1.event_id != event2.event_id
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        ProjectCreated.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end

    test "raises when project_id is missing" do
      assert_raise ArgumentError, fn ->
        ProjectCreated.new(%{
          aggregate_id: "123",
          actor_id: "123",
          workspace_id: "ws-1",
          user_id: "u-1",
          name: "N",
          slug: "n"
        })
      end
    end

    test "allows custom metadata" do
      event = ProjectCreated.new(Map.put(@valid_attrs, :metadata, %{source: "api"}))

      assert event.metadata == %{source: "api"}
    end
  end
end
