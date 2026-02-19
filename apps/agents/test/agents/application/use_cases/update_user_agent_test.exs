defmodule Agents.Application.UseCases.UpdateUserAgentTest do
  use Agents.DataCase, async: false

  alias Agents.Application.UseCases.UpdateUserAgent
  alias Agents.Domain.Events.AgentUpdated
  alias Perme8.Events.TestEventBus

  import Agents.Test.AccountsFixtures
  import Agents.AgentsFixtures

  # Mock notifier for testing
  defmodule MockNotifier do
    def notify_agent_updated(_agent, _workspace_ids), do: :ok
  end

  describe "execute/4 - event emission" do
    test "emits AgentUpdated event via event_bus" do
      ensure_test_event_bus_started()

      user = user_fixture()
      agent = agent_fixture(user)

      assert {:ok, updated_agent} =
               UpdateUserAgent.execute(agent.id, user.id, %{name: "Updated Agent"},
                 notifier: MockNotifier,
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
      ensure_test_event_bus_started()

      user = user_fixture()

      assert {:error, :not_found} =
               UpdateUserAgent.execute(Ecto.UUID.generate(), user.id, %{name: "X"},
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
