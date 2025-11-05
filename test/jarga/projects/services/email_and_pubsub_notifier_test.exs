defmodule Jarga.Projects.Services.EmailAndPubSubNotifierTest do
  use ExUnit.Case, async: true

  alias Jarga.Projects.Services.EmailAndPubSubNotifier

  describe "notify_project_created/1" do
    test "returns :ok for valid inputs" do
      project = %Jarga.Projects.Project{
        id: "project-123",
        name: "Test Project",
        slug: "test-project",
        workspace_id: "workspace-456"
      }

      assert :ok = EmailAndPubSubNotifier.notify_project_created(project)
    end
  end

  describe "notify_project_deleted/2" do
    test "returns :ok for valid inputs" do
      project = %Jarga.Projects.Project{
        id: "project-123",
        name: "Test Project",
        slug: "test-project",
        workspace_id: "workspace-456"
      }

      workspace_id = "workspace-456"

      assert :ok = EmailAndPubSubNotifier.notify_project_deleted(project, workspace_id)
    end
  end

  describe "notify_project_updated/1" do
    test "returns :ok for valid inputs" do
      project = %Jarga.Projects.Project{
        id: "project-123",
        name: "Test Project",
        slug: "test-project",
        workspace_id: "workspace-456"
      }

      assert :ok = EmailAndPubSubNotifier.notify_project_updated(project)
    end
  end
end
