defmodule Agents.Application.Behaviours.PubSubNotifierBehaviour do
  @moduledoc """
  Behaviour defining the PubSub notification contract for agents.
  """

  @type agent :: struct()
  @type workspace_ids :: [Ecto.UUID.t()]

  @callback notify_agent_updated(agent, workspace_ids) :: :ok
  @callback notify_workspace_associations_changed(agent, workspace_ids, workspace_ids) :: :ok
  @callback notify_agent_deleted(agent, workspace_ids) :: :ok
end
