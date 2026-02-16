defmodule Agents.Application.UseCases.ValidateAgentParams do
  @moduledoc """
  Use case for validating agent parameters without persisting.

  Useful for form validation to provide real-time feedback to users.
  """

  @default_agent_schema Agents.Infrastructure.Schemas.AgentSchema

  @doc """
  Validates agent parameters.

  ## Parameters
  - `attrs` - Map of agent attributes to validate
  - `opts` - Keyword list of options:
    - `:agent_schema` - Optional schema module (default: AgentSchema)

  ## Returns
  - `%Ecto.Changeset{}` - Changeset with validation results
  """
  def execute(attrs, opts \\ []) do
    agent_schema = Keyword.get(opts, :agent_schema, @default_agent_schema)

    struct(agent_schema)
    |> agent_schema.changeset(attrs)
    |> Map.put(:action, :validate)
  end
end
