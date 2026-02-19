defmodule Jarga.Projects.UseCases.UpdateProjectTest do
  use Jarga.DataCase, async: false

  alias Jarga.Projects.Application.UseCases.UpdateProject
  alias Jarga.Projects.Domain.Events.ProjectUpdated
  alias Perme8.Events.TestEventBus

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  # Mock notifier for testing
  defmodule MockNotifier do
    def notify_project_updated(_project), do: :ok
  end

  describe "execute/2 - event emission" do
    test "emits ProjectUpdated event via event_bus" do
      ensure_test_event_bus_started()

      owner = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        project_id: project.id,
        attrs: %{name: "Updated Name"}
      }

      opts = [notifier: MockNotifier, event_bus: TestEventBus]

      assert {:ok, updated_project} = UpdateProject.execute(params, opts)

      assert [%ProjectUpdated{} = event] =
               TestEventBus.get_events()

      assert event.project_id == updated_project.id
      assert event.workspace_id == workspace.id
      assert event.user_id == owner.id
      assert event.name == "Updated Name"
      assert event.aggregate_id == updated_project.id
      assert event.actor_id == owner.id
    end

    test "does not emit event when update fails" do
      ensure_test_event_bus_started()

      owner = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        project_id: project.id,
        attrs: %{name: ""}
      }

      opts = [notifier: MockNotifier, event_bus: TestEventBus]

      assert {:error, _changeset} = UpdateProject.execute(params, opts)
      assert [] = TestEventBus.get_events()
    end
  end

  defp ensure_test_event_bus_started do
    case Process.whereis(TestEventBus) do
      nil ->
        {:ok, _pid} = TestEventBus.start_link([])
        :ok

      _pid ->
        TestEventBus.reset()
    end
  end
end
