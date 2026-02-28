defmodule Agents.Application.UseCases.SyncAgentWorkspacesTest do
  use Agents.DataCase, async: true

  alias Agents.Application.UseCases.SyncAgentWorkspaces
  alias Agents.Domain.Events.AgentAddedToWorkspace
  alias Agents.Domain.Events.AgentRemovedFromWorkspace
  alias Perme8.Events.TestEventBus

  import Agents.Test.AccountsFixtures
  import Agents.Test.WorkspacesFixtures
  import Agents.AgentsFixtures

  setup do
    TestEventBus.start_global()
    :ok
  end

  describe "execute/4 - event emission" do
    test "emits AgentAddedToWorkspace events for new workspaces" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      agent = agent_fixture(user)

      assert :ok =
               SyncAgentWorkspaces.execute(agent.id, user.id, [workspace.id],
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
      user = user_fixture()
      workspace = workspace_fixture(user)
      agent = agent_fixture(user)

      # First, add agent to workspace
      :ok =
        SyncAgentWorkspaces.execute(agent.id, user.id, [workspace.id], event_bus: TestEventBus)

      # Reset event bus
      TestEventBus.reset()

      # Now remove by syncing with empty list
      :ok =
        SyncAgentWorkspaces.execute(agent.id, user.id, [], event_bus: TestEventBus)

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
      user = user_fixture()

      assert {:error, :not_found} =
               SyncAgentWorkspaces.execute(Ecto.UUID.generate(), user.id, [],
                 event_bus: TestEventBus
               )

      assert [] = TestEventBus.get_events()
    end
  end
end
