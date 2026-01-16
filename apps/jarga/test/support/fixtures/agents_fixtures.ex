defmodule Jarga.AgentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Jarga.Agents` context.
  """

  use Boundary,
    top_level?: true,
    deps: [Jarga.Agents, Jarga.AccountsFixtures, Jarga.WorkspacesFixtures],
    exports: []

  import Jarga.AccountsFixtures

  @doc """
  Generate a user agent.
  """
  def user_agent_fixture(attrs \\ %{}) do
    user_id = attrs[:user_id] || user_fixture().id

    agent_params = %{
      user_id: user_id,
      name: attrs[:name] || "Test Agent",
      description: attrs[:description],
      system_prompt: attrs[:system_prompt],
      model: attrs[:model],
      temperature: attrs[:temperature],
      visibility: attrs[:visibility] || "PRIVATE",
      enabled: Map.get(attrs, :enabled, true)
    }

    {:ok, agent} = Jarga.Agents.create_user_agent(agent_params)
    agent
  end

  @doc """
  Convenience alias for agent_fixture/2.
  Accepts a user as first parameter and attrs as second parameter.
  """
  def agent_fixture(user, attrs \\ %{}) do
    attrs_with_defaults =
      attrs
      |> Map.put(:user_id, user.id)
      |> Map.put_new(:temperature, 0.7)

    user_agent_fixture(attrs_with_defaults)
  end
end
