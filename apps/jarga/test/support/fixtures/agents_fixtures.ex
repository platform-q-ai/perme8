defmodule Jarga.AgentsFixtures do
  @moduledoc """
  Delegation wrapper for backwards compatibility.
  Real fixtures live in Agents.AgentsFixtures (apps/agents/).
  """

  defdelegate user_agent_fixture(attrs \\ %{}), to: Agents.AgentsFixtures
  defdelegate agent_fixture(user, attrs \\ %{}), to: Agents.AgentsFixtures
end
