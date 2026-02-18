defmodule Agents.Application.UseCases.DeleteUserAgentTest do
  use Agents.DataCase, async: false

  alias Agents.Application.UseCases.DeleteUserAgent

  import Agents.Test.AccountsFixtures
  import Agents.AgentsFixtures

  # Mock notifier for testing
  defmodule MockNotifier do
    def notify_agent_deleted(_agent, _workspace_ids), do: :ok
  end

  describe "execute/3 - event emission" do
    test "emits AgentDeleted event via event_bus" do
      ensure_test_event_bus_started()

      user = user_fixture()
      agent = agent_fixture(user)

      assert {:ok, _deleted_agent} =
               DeleteUserAgent.execute(agent.id, user.id,
                 notifier: MockNotifier,
                 event_bus: Perme8.Events.TestEventBus
               )

      assert [%Agents.Domain.Events.AgentDeleted{} = event] =
               Perme8.Events.TestEventBus.get_events()

      assert event.agent_id == agent.id
      assert event.user_id == user.id
      assert event.aggregate_id == agent.id
      assert event.actor_id == user.id
    end

    test "does not emit event when delete fails (not found)" do
      ensure_test_event_bus_started()

      user = user_fixture()

      assert {:error, :not_found} =
               DeleteUserAgent.execute(Ecto.UUID.generate(), user.id,
                 notifier: MockNotifier,
                 event_bus: Perme8.Events.TestEventBus
               )

      assert [] = Perme8.Events.TestEventBus.get_events()
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
