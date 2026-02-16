defmodule Agents.Application.Behaviours.AgentRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the agent repository contract.
  """

  @type agent :: struct()
  @type agent_id :: Ecto.UUID.t()
  @type user_id :: Ecto.UUID.t()
  @type attrs :: map()

  @callback get(agent_id) :: agent | nil
  @callback get_agent_for_user(user_id, agent_id) :: agent | nil
  @callback create_agent(attrs) :: {:ok, agent} | {:error, Ecto.Changeset.t()}
  @callback delete_agent(agent) :: {:ok, agent} | {:error, Ecto.Changeset.t()}
  @callback update_agent(agent, attrs) :: {:ok, agent} | {:error, Ecto.Changeset.t()}
  @callback list_agents_for_user(user_id) :: [agent]
  @callback list_viewable_agents(user_id) :: [agent]
end
