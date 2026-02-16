defmodule Agents.Domain.AgentCloner do
  @moduledoc """
  Pure business logic for cloning agents.

  Creates attribute maps for cloned agents:
  - Copies all configuration (system_prompt, model, temperature, etc.)
  - Appends " (Copy)" to name
  - Sets visibility to PRIVATE
  - Sets new user_id
  - Does NOT include workspace associations
  """

  @visibility_private "PRIVATE"
  @clone_suffix " (Copy)"

  @type agent :: %{
          name: String.t(),
          description: String.t(),
          system_prompt: String.t(),
          model: String.t(),
          temperature: float(),
          user_id: String.t(),
          visibility: String.t()
        }
  @type user_id :: String.t()

  @doc """
  Generates attributes for a cloned agent.

  Copies all configuration from the original agent and applies clone rules:
  - Name: appends " (Copy)" suffix
  - Visibility: always PRIVATE
  - User ID: set to new owner
  - Configuration: copied from original (system_prompt, model, temperature, etc.)
  - Workspace associations: NOT included (clones start without workspace associations)

  ## Parameters
  - `original_agent` - Map containing original agent attributes
  - `new_user_id` - ID of the user cloning the agent

  ## Returns
  Map of attributes suitable for creating a new agent record.

  ## Examples

      iex> original = %{
      ...>   name: "Research Assistant",
      ...>   description: "Helps with research",
      ...>   system_prompt: "You are a research assistant",
      ...>   model: "gpt-4",
      ...>   temperature: 0.7,
      ...>   user_id: "owner-123",
      ...>   visibility: "SHARED"
      ...> }
      iex> AgentCloner.clone_attrs(original, "cloner-456")
      %{
        name: "Research Assistant (Copy)",
        description: "Helps with research",
        system_prompt: "You are a research assistant",
        model: "gpt-4",
        temperature: 0.7,
        user_id: "cloner-456",
        visibility: "PRIVATE"
      }
  """
  @spec clone_attrs(agent(), user_id()) :: map()
  def clone_attrs(original_agent, new_user_id) do
    %{
      name: original_agent.name <> @clone_suffix,
      description: original_agent.description,
      system_prompt: original_agent.system_prompt,
      model: original_agent.model,
      temperature: original_agent.temperature,
      user_id: new_user_id,
      visibility: @visibility_private
    }
  end
end
