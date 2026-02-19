defmodule Jarga.Projects.Services.EmailAndPubSubNotifierTest do
  use ExUnit.Case, async: true

  alias Jarga.Projects.Infrastructure.Notifiers.EmailAndPubSubNotifier

  describe "notify_project_created/1" do
    test "returns :ok (no-op — EventBus handles delivery now)" do
      project = %Jarga.Projects.Domain.Entities.Project{
        id: "project-123",
        name: "Test Project",
        slug: "test-project",
        workspace_id: "workspace-456"
      }

      assert :ok = EmailAndPubSubNotifier.notify_project_created(project)
    end

    test "does not broadcast legacy PubSub tuple" do
      project = %Jarga.Projects.Domain.Entities.Project{
        id: "project-123",
        name: "Test Project",
        slug: "test-project",
        workspace_id: "workspace-456"
      }

      Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:workspace-456")

      EmailAndPubSubNotifier.notify_project_created(project)

      refute_receive {:project_added, _}
    end
  end

  describe "notify_project_deleted/2" do
    test "returns :ok (no-op — EventBus handles delivery now)" do
      project = %Jarga.Projects.Domain.Entities.Project{
        id: "project-123",
        name: "Test Project",
        slug: "test-project",
        workspace_id: "workspace-456"
      }

      workspace_id = "workspace-456"

      assert :ok = EmailAndPubSubNotifier.notify_project_deleted(project, workspace_id)
    end

    test "does not broadcast legacy PubSub tuple" do
      project = %Jarga.Projects.Domain.Entities.Project{
        id: "project-123",
        name: "Test Project",
        slug: "test-project",
        workspace_id: "workspace-456"
      }

      Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:workspace-456")

      EmailAndPubSubNotifier.notify_project_deleted(project, "workspace-456")

      refute_receive {:project_removed, _}
    end
  end

  describe "notify_project_updated/1" do
    test "returns :ok (no-op — EventBus handles delivery now)" do
      project = %Jarga.Projects.Domain.Entities.Project{
        id: "project-123",
        name: "Test Project",
        slug: "test-project",
        workspace_id: "workspace-456"
      }

      assert :ok = EmailAndPubSubNotifier.notify_project_updated(project)
    end

    test "does not broadcast legacy PubSub tuple" do
      project = %Jarga.Projects.Domain.Entities.Project{
        id: "project-123",
        name: "Test Project",
        slug: "test-project",
        workspace_id: "workspace-456"
      }

      Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:workspace-456")

      EmailAndPubSubNotifier.notify_project_updated(project)

      refute_receive {:project_updated, _, _}
    end
  end
end
