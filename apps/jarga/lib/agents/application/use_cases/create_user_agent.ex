defmodule Jarga.Agents.Application.UseCases.CreateUserAgent do
  @moduledoc """
  Use case for creating a user-owned agent.

  Creates an agent with:
  - Required user_id (owner)
  - Default visibility: PRIVATE
  - No workspace associations by default
  """

  alias Jarga.Agents.Infrastructure.Repositories.AgentRepository

  @doc """
  Creates a new agent owned by the specified user.

  ## Parameters
  - `attrs` - Map of agent attributes including user_id

  ## Returns
  - `{:ok, agent}` - Successfully created agent
  - `{:error, changeset}` - Validation error
  """
  def execute(attrs) do
    AgentRepository.create_agent(attrs)
  end
end
