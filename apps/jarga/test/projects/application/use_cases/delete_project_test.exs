defmodule Jarga.Projects.UseCases.DeleteProjectTest do
  use Jarga.DataCase, async: false

  alias Jarga.Projects.Application.UseCases.DeleteProject
  alias Jarga.Projects

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  # Mock notifier for testing
  defmodule MockNotifier do
    def notify_project_deleted(_project, _workspace_id), do: :ok
  end

  describe "execute/2 - successful project deletion" do
    test "owner can delete their own project" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        project_id: project.id
      }

      opts = [notifier: MockNotifier]

      assert {:ok, deleted_project} = DeleteProject.execute(params, opts)
      assert deleted_project.id == project.id

      # Verify project is actually deleted
      assert Projects.get_project(owner, workspace.id, project.id) == {:error, :project_not_found}
    end

    test "member can delete their own project" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)

      # Add member to workspace
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      project = project_fixture(member, workspace)

      params = %{
        actor: member,
        workspace_id: workspace.id,
        project_id: project.id
      }

      opts = [notifier: MockNotifier]

      assert {:ok, deleted_project} = DeleteProject.execute(params, opts)
      assert deleted_project.id == project.id
    end

    test "workspace admin can delete any project" do
      owner = user_fixture()
      admin = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)

      # Add admin and member to workspace
      {:ok, _} = invite_and_accept_member(owner, workspace.id, admin.email, :admin)
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      # Create project owned by member
      project = project_fixture(member, workspace)

      params = %{
        actor: admin,
        workspace_id: workspace.id,
        project_id: project.id
      }

      opts = [notifier: MockNotifier]

      assert {:ok, deleted_project} = DeleteProject.execute(params, opts)
      assert deleted_project.id == project.id
    end

    test "workspace owner can delete any project" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)

      # Add member to workspace
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      # Create project owned by member
      project = project_fixture(member, workspace)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        project_id: project.id
      }

      opts = [notifier: MockNotifier]

      assert {:ok, deleted_project} = DeleteProject.execute(params, opts)
      assert deleted_project.id == project.id
    end
  end

  describe "execute/2 - authorization failures" do
    test "member cannot delete another member's project" do
      owner = user_fixture()
      member1 = user_fixture()
      member2 = user_fixture()
      workspace = workspace_fixture(owner)

      # Add both members to workspace
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member1.email, :member)
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member2.email, :member)

      # Create project owned by member1
      project = project_fixture(member1, workspace)

      # Try to delete as member2
      params = %{
        actor: member2,
        workspace_id: workspace.id,
        project_id: project.id
      }

      assert {:error, :forbidden} = DeleteProject.execute(params, [])

      # Verify project still exists
      assert {:ok, _} = Projects.get_project(member1, workspace.id, project.id)
    end

    test "non-member cannot delete project" do
      owner = user_fixture()
      non_member = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)

      params = %{
        actor: non_member,
        workspace_id: workspace.id,
        project_id: project.id
      }

      assert {:error, :unauthorized} = DeleteProject.execute(params, [])

      # Verify project still exists
      assert {:ok, _} = Projects.get_project(owner, workspace.id, project.id)
    end

    test "returns error when workspace doesn't exist" do
      user = user_fixture()
      fake_workspace_id = Ecto.UUID.generate()
      fake_project_id = Ecto.UUID.generate()

      params = %{
        actor: user,
        workspace_id: fake_workspace_id,
        project_id: fake_project_id
      }

      assert {:error, :workspace_not_found} = DeleteProject.execute(params, [])
    end

    test "returns error when project doesn't exist" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      fake_project_id = Ecto.UUID.generate()

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        project_id: fake_project_id
      }

      assert {:error, :project_not_found} = DeleteProject.execute(params, [])
    end

    test "returns error when project belongs to different workspace" do
      owner = user_fixture()
      workspace1 = workspace_fixture(owner)
      workspace2 = workspace_fixture(owner)
      project = project_fixture(owner, workspace2)

      params = %{
        actor: owner,
        workspace_id: workspace1.id,
        project_id: project.id
      }

      assert {:error, :project_not_found} = DeleteProject.execute(params, [])
    end
  end

  describe "execute/2 - event emission" do
    test "emits ProjectDeleted event via event_bus" do
      ensure_test_event_bus_started()

      owner = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        project_id: project.id
      }

      opts = [notifier: MockNotifier, event_bus: Perme8.Events.TestEventBus]

      assert {:ok, deleted_project} = DeleteProject.execute(params, opts)

      assert [%Jarga.Projects.Domain.Events.ProjectDeleted{} = event] =
               Perme8.Events.TestEventBus.get_events()

      assert event.project_id == deleted_project.id
      assert event.workspace_id == workspace.id
      assert event.user_id == owner.id
      assert event.aggregate_id == deleted_project.id
      assert event.actor_id == owner.id
    end

    test "does not emit event when deletion fails (unauthorized)" do
      ensure_test_event_bus_started()

      owner = user_fixture()
      non_member = user_fixture()
      workspace = workspace_fixture(owner)
      _project = project_fixture(owner, workspace)

      params = %{
        actor: non_member,
        workspace_id: workspace.id,
        project_id: Ecto.UUID.generate()
      }

      opts = [notifier: MockNotifier, event_bus: Perme8.Events.TestEventBus]

      assert {:error, _reason} = DeleteProject.execute(params, opts)
      assert [] = Perme8.Events.TestEventBus.get_events()
    end
  end

  describe "execute/2 - notification behavior" do
    test "calls notifier with deleted project and workspace_id" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)

      # Create a test process to capture notification
      test_pid = self()

      defmodule TestNotifier do
        def notify_project_deleted(project, workspace_id) do
          send(Process.get(:test_pid), {:notified, project, workspace_id})
          :ok
        end
      end

      Process.put(:test_pid, test_pid)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        project_id: project.id
      }

      opts = [notifier: TestNotifier]

      assert {:ok, deleted_project} = DeleteProject.execute(params, opts)

      assert_receive {:notified, notified_project, notified_workspace_id}
      assert notified_project.id == deleted_project.id
      assert notified_workspace_id == workspace.id
    end

    test "uses default notifier when not specified" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        project_id: project.id
      }

      # Should not raise error with default notifier
      assert {:ok, _deleted_project} = DeleteProject.execute(params, [])
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
