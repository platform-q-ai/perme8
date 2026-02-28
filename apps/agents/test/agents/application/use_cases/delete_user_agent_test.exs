defmodule Agents.Application.UseCases.DeleteUserAgentTest do
  use Agents.DataCase, async: true

  alias Agents.Application.UseCases.DeleteUserAgent
  alias Agents.Domain.Events.AgentDeleted
  alias Perme8.Events.TestEventBus

  import Agents.Test.AccountsFixtures
  import Agents.AgentsFixtures

  setup do
    TestEventBus.start_global()
    :ok
  end

  describe "execute/3 - event emission" do
    test "emits AgentDeleted event via event_bus" do
      user = user_fixture()
      agent = agent_fixture(user)

      assert {:ok, _deleted_agent} =
               DeleteUserAgent.execute(agent.id, user.id, event_bus: TestEventBus)

      assert [%AgentDeleted{} = event] =
               TestEventBus.get_events()

      assert event.agent_id == agent.id
      assert event.user_id == user.id
      assert event.aggregate_id == agent.id
      assert event.actor_id == user.id
    end

    test "does not emit event when delete fails (not found)" do
      user = user_fixture()

      assert {:error, :not_found} =
               DeleteUserAgent.execute(Ecto.UUID.generate(), user.id, event_bus: TestEventBus)

      assert [] = TestEventBus.get_events()
    end
  end
end
