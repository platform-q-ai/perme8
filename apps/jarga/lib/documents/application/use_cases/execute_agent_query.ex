defmodule Jarga.Documents.Application.UseCases.ExecuteAgentQuery do
  @moduledoc """
  Executes an agent query command within document editor context.

  Parses `@j agent_name Question` syntax, looks up the agent by name in the workspace,
  and delegates to `Agents.agent_query/2` with the agent's custom settings and document context.

  ## Business Rules

  - Agent must exist in the workspace (user's own agents or shared agents)
  - Agent must be enabled
  - Command must match `@j agent_name Question` format
  - Agent receives full document content as context
  - Agent's custom system_prompt, model, and temperature are used

  ## Responsibilities

  - Parse command text using domain parser
  - Look up agent by name in workspace (case-insensitive)
  - Validate agent is enabled
  - Delegate to Agents.agent_query with agent-specific settings
  """

  alias Jarga.Agents
  alias Jarga.Documents.Domain.AgentQueryParser

  @doc """
  Executes the agent query command.

  ## Parameters

    - `params` - Map containing:
      - `:command` - The command text (e.g., "@j my-agent What is this?")
      - `:user` - User executing the query
      - `:workspace_id` - ID of the workspace
      - `:assigns` - LiveView assigns with document context
      - `:node_id` - Node ID for streaming responses

    - `caller_pid` - PID to send streaming responses to

  ## Returns

    - `{:ok, pid}` - Agent query started successfully
    - `{:error, :invalid_command_format}` - Command parsing failed
    - `{:error, :agent_not_found}` - Agent doesn't exist in workspace
    - `{:error, :agent_disabled}` - Agent exists but is disabled

  ## Examples

      iex> execute(%{command: "@j my-agent Help", user: user, workspace_id: ws_id, assigns: assigns, node_id: "node_1"}, self())
      {:ok, #PID<...>}
  """
  @spec execute(map(), pid()) :: {:ok, pid()} | {:error, atom()}
  def execute(params, caller_pid) do
    %{
      command: command,
      user: user,
      workspace_id: workspace_id,
      assigns: assigns,
      node_id: node_id
    } = params

    with {:ok, parsed} <- parse_command(command),
         {:ok, agent} <- find_agent(parsed.agent_name, workspace_id, user.id) do
      # Delegate to Agents.agent_query with agent and context
      query_params = %{
        question: parsed.question,
        agent: agent,
        assigns: assigns,
        node_id: node_id
      }

      Agents.agent_query(query_params, caller_pid)
    end
  end

  # Parse the @j command text
  defp parse_command(command) do
    case AgentQueryParser.parse(command) do
      {:ok, parsed} ->
        {:ok, parsed}

      {:error, _reason} ->
        {:error, :invalid_command_format}
    end
  end

  # Find agent by name in workspace (case-insensitive)
  # Fetches all agents once and checks enabled status
  defp find_agent(agent_name, workspace_id, user_id) do
    all_agents = Agents.get_workspace_agents_list(workspace_id, user_id, enabled_only: false)

    case find_agent_by_name(all_agents, agent_name) do
      nil ->
        {:error, :agent_not_found}

      %{enabled: false} ->
        {:error, :agent_disabled}

      agent ->
        {:ok, agent}
    end
  end

  # Find agent by name (case-insensitive match)
  defp find_agent_by_name(agents, agent_name) do
    Enum.find(agents, fn agent ->
      String.downcase(agent.name) == String.downcase(agent_name)
    end)
  end
end
