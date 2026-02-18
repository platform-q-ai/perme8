defmodule Jarga.Projects.UseCases.CreateProjectTest do
  use Jarga.DataCase, async: false

  alias Jarga.Projects.Application.UseCases.CreateProject

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  # Mock notifier for testing
  defmodule MockNotifier do
    def notify_project_created(_project), do: :ok
  end

  describe "execute/2 - successful project creation" do
    test "creates project when actor is workspace owner" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{
          name: "New Project",
          description: "A new project",
          color: "#10B981"
        }
      }

      opts = [notifier: MockNotifier]

      assert {:ok, project} = CreateProject.execute(params, opts)
      assert project.name == "New Project"
      assert project.description == "A new project"
      assert project.color == "#10B981"
      assert project.user_id == owner.id
      assert project.workspace_id == workspace.id
      assert project.slug == "new-project"
    end

    test "creates project when actor is workspace admin" do
      owner = user_fixture()
      admin = user_fixture()
      workspace = workspace_fixture(owner)

      # Add admin as member
      {:ok, _} = invite_and_accept_member(owner, workspace.id, admin.email, :admin)

      params = %{
        actor: admin,
        workspace_id: workspace.id,
        attrs: %{name: "Admin Project"}
      }

      opts = [notifier: MockNotifier]

      assert {:ok, project} = CreateProject.execute(params, opts)
      assert project.name == "Admin Project"
      assert project.user_id == admin.id
    end

    test "creates project when actor is workspace member" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)

      # Add member
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      params = %{
        actor: member,
        workspace_id: workspace.id,
        attrs: %{name: "Member Project"}
      }

      opts = [notifier: MockNotifier]

      assert {:ok, project} = CreateProject.execute(params, opts)
      assert project.name == "Member Project"
      assert project.user_id == member.id
    end

    test "generates unique slug when duplicate names exist" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      # Create first project
      params1 = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{name: "My Project"}
      }

      opts = [notifier: MockNotifier]

      assert {:ok, project1} = CreateProject.execute(params1, opts)
      assert project1.slug == "my-project"

      # Create second project with same name
      params2 = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{name: "My Project"}
      }

      assert {:ok, project2} = CreateProject.execute(params2, opts)
      assert project2.slug != "my-project"
      assert String.starts_with?(project2.slug, "my-project-")
    end

    test "creates project with minimal attributes" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{name: "Minimal Project"}
      }

      opts = [notifier: MockNotifier]

      assert {:ok, project} = CreateProject.execute(params, opts)
      assert project.name == "Minimal Project"
    end
  end

  describe "execute/2 - authorization failures" do
    test "returns error when actor is not a workspace member" do
      owner = user_fixture()
      non_member = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: non_member,
        workspace_id: workspace.id,
        attrs: %{name: "Unauthorized Project"}
      }

      assert {:error, :unauthorized} = CreateProject.execute(params, [])
    end

    test "returns error when workspace doesn't exist" do
      user = user_fixture()
      fake_workspace_id = Ecto.UUID.generate()

      params = %{
        actor: user,
        workspace_id: fake_workspace_id,
        attrs: %{name: "Project"}
      }

      assert {:error, :workspace_not_found} = CreateProject.execute(params, [])
    end
  end

  describe "execute/2 - validation failures" do
    test "returns error when name is missing" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{description: "No name"}
      }

      assert {:error, changeset} = CreateProject.execute(params, [])
      assert "can't be blank" in errors_on(changeset).name
    end

    test "returns error when name is empty string" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{name: ""}
      }

      assert {:error, changeset} = CreateProject.execute(params, [])
      assert "can't be blank" in errors_on(changeset).name
    end
  end

  describe "execute/2 - event emission" do
    test "emits ProjectCreated event via event_bus" do
      ensure_test_event_bus_started()

      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{name: "Event Project", description: "Testing events"}
      }

      opts = [notifier: MockNotifier, event_bus: Perme8.Events.TestEventBus]

      assert {:ok, project} = CreateProject.execute(params, opts)

      assert [%Jarga.Projects.Domain.Events.ProjectCreated{} = event] =
               Perme8.Events.TestEventBus.get_events()

      assert event.project_id == project.id
      assert event.workspace_id == workspace.id
      assert event.user_id == owner.id
      assert event.name == project.name
      assert event.slug == project.slug
      assert event.aggregate_id == project.id
      assert event.actor_id == owner.id
    end

    test "does not emit event when project creation fails" do
      ensure_test_event_bus_started()

      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{description: "No name - will fail"}
      }

      opts = [notifier: MockNotifier, event_bus: Perme8.Events.TestEventBus]

      assert {:error, _changeset} = CreateProject.execute(params, opts)
      assert [] = Perme8.Events.TestEventBus.get_events()
    end
  end

  describe "execute/2 - notification behavior" do
    test "calls notifier with created project" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      # Create a test process to capture notification
      test_pid = self()

      defmodule TestNotifier do
        def notify_project_created(project) do
          send(Process.get(:test_pid), {:notified, project})
          :ok
        end
      end

      Process.put(:test_pid, test_pid)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{name: "Notified Project"}
      }

      opts = [notifier: TestNotifier]

      assert {:ok, project} = CreateProject.execute(params, opts)

      assert_receive {:notified, notified_project}
      assert notified_project.id == project.id
    end

    test "uses default notifier when not specified" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{name: "Default Notifier Project"}
      }

      # Should not raise error with default notifier
      assert {:ok, _project} = CreateProject.execute(params, [])
    end
  end

  defp ensure_test_event_bus_started do
    case Process.whereis(Perme8.Events.TestEventBus) do
      nil ->
        {:ok, _pid} = Perme8.Events.TestEventBus.start_link([])
        :ok

      _pid ->
        Perme8.Events.TestEventBus.reset()
    end
  end
end
