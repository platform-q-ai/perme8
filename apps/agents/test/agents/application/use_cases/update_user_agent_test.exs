defmodule Agents.Application.UseCases.UpdateUserAgentTest do
  use Agents.DataCase, async: true

  alias Agents.Application.UseCases.UpdateUserAgent
  alias Agents.Domain.Events.AgentUpdated
  alias Perme8.Events.TestEventBus

  import Agents.Test.AccountsFixtures
  import Agents.AgentsFixtures

  setup do
    TestEventBus.start_global()
    :ok
  end

  describe "execute/4 - event emission" do
    test "emits AgentUpdated event via event_bus" do
      user = user_fixture()
      agent = agent_fixture(user)

      assert {:ok, _updated_agent} =
               UpdateUserAgent.execute(agent.id, user.id, %{name: "Updated Agent"},
                 event_bus: TestEventBus
               )

      assert [%AgentUpdated{} = event] =
               TestEventBus.get_events()

      assert event.agent_id == agent.id
      assert event.user_id == user.id
      assert event.aggregate_id == agent.id
      assert event.actor_id == user.id
    end

    test "does not emit event when update fails (not found)" do
      user = user_fixture()

      assert {:error, :not_found} =
               UpdateUserAgent.execute(Ecto.UUID.generate(), user.id, %{name: "X"},
                 event_bus: TestEventBus
               )

      assert [] = TestEventBus.get_events()
    end
  end
end
