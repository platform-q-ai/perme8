defmodule Agents.Application.UseCases.SyncAgentWorkspacesTest do
  use Agents.DataCase, async: false

  alias Agents.Application.UseCases.SyncAgentWorkspaces
  alias Agents.Domain.Events.AgentAddedToWorkspace
  alias Agents.Domain.Events.AgentRemovedFromWorkspace
  alias Perme8.Events.TestEventBus

  import Agents.Test.AccountsFixtures
  import Agents.Test.WorkspacesFixtures
  import Agents.AgentsFixtures

  # Mock notifier for testing
  defmodule MockNotifier do
    def notify_workspace_associations_changed(_agent, _added, _removed), do: :ok
  end

  describe "execute/4 - event emission" do
    test "emits AgentAddedToWorkspace events for new workspaces" do
      ensure_test_event_bus_started()

      user = user_fixture()
      workspace = workspace_fixture(user)
      agent = agent_fixture(user)

      assert :ok =
               SyncAgentWorkspaces.execute(agent.id, user.id, [workspace.id],
                 notifier: MockNotifier,
                 event_bus: TestEventBus
               )

      events = TestEventBus.get_events()

      added_events =
        Enum.filter(events, &match?(%AgentAddedToWorkspace{}, &1))

      assert length(added_events) == 1
      event = hd(added_events)
      assert event.agent_id == agent.id
      assert event.workspace_id == workspace.id
      assert event.user_id == user.id
    end

    test "emits AgentRemovedFromWorkspace events when removing from workspaces" do
      ensure_test_event_bus_started()

      user = user_fixture()
      workspace = workspace_fixture(user)
      agent = agent_fixture(user)

      # First, add agent to workspace
      :ok =
        SyncAgentWorkspaces.execute(agent.id, user.id, [workspace.id],
          notifier: MockNotifier,
          event_bus: TestEventBus
        )

      # Reset event bus
      TestEventBus.reset()

      # Now remove by syncing with empty list
      :ok =
        SyncAgentWorkspaces.execute(agent.id, user.id, [],
          notifier: MockNotifier,
          event_bus: TestEventBus
        )

      events = TestEventBus.get_events()

      removed_events =
        Enum.filter(events, &match?(%AgentRemovedFromWorkspace{}, &1))

      assert length(removed_events) == 1
      event = hd(removed_events)
      assert event.agent_id == agent.id
      assert event.workspace_id == workspace.id
      assert event.user_id == user.id
    end

    test "does not emit events when agent not found" do
      ensure_test_event_bus_started()

      user = user_fixture()

      assert {:error, :not_found} =
               SyncAgentWorkspaces.execute(Ecto.UUID.generate(), user.id, [],
                 notifier: MockNotifier,
                 event_bus: TestEventBus
               )

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
