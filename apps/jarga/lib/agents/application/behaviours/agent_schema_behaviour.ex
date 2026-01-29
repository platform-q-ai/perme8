defmodule Jarga.Agents.Application.Behaviours.AgentSchemaBehaviour do
  @moduledoc """
  Behaviour defining the agent schema contract.
  """

  @callback changeset(struct(), map()) :: Ecto.Changeset.t()
end
