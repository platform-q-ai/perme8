defmodule ChatSetupAgentsConfigSteps do
  @moduledoc """
  Step definitions for Chat Panel Agent Configuration and Selection.

  Covers:
  - Agent configuration with model, temperature, etc.
  - Agent system prompt setup
  - Agent selection in chat panel

  Related modules:
  - ChatSetupAgentsSteps - Basic agent setup
  - ChatSetupAgentsWorkspaceSteps - Workspace agent configuration
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers
  import Jarga.AgentsFixtures

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp parse_agent_config(rows) do
    Enum.reduce(rows, %{}, fn row, acc ->
      case row do
        [key, value] when is_binary(key) and is_binary(value) ->
          parse_config_row(String.trim(key), String.trim(value), acc)

        _ ->
          acc
      end
    end)
  end

  defp parse_config_row("Model", value, acc), do: Map.put(acc, :model, value)

  defp parse_config_row("Temperature", value, acc),
    do: Map.put(acc, :temperature, String.to_float(value))

  defp parse_config_row(_key, _value, acc), do: acc

  defp sync_agent_to_workspace_if_exists(_agent, _user, nil), do: :ok

  defp sync_agent_to_workspace_if_exists(agent, user, workspace) do
    :ok = Jarga.Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])
  end

  # ============================================================================
  # AGENT CONFIGURATION STEPS
  # ============================================================================

  step "agent {string} is configured with:", %{args: [agent_name]} = context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]
    rows = context.datatable.raw || context.datatable.rows || []

    config = parse_agent_config(rows)

    agent =
      agent_fixture(user, %{
        name: agent_name,
        model: config[:model] || "gpt-4o-mini",
        temperature: config[:temperature] || 0.7,
        enabled: true
      })

    sync_agent_to_workspace_if_exists(agent, user, workspace)
    agents = context[:agents] || %{}

    {:ok,
     context
     |> Map.put(:agents, Map.put(agents, agent_name, agent))
     |> Map.put(:agent, agent)}
  end

  step "agent {string} has no system prompt", %{args: [agent_name]} = context do
    user = context[:current_user] || raise "No user logged in. Run 'Given I am logged in' first."

    workspace =
      context[:workspace] || context[:current_workspace] ||
        raise "No workspace. Set :workspace or :current_workspace in a prior step."

    agent =
      Jarga.AgentsFixtures.agent_fixture(user, %{
        name: agent_name,
        system_prompt: nil,
        enabled: true
      })

    :ok = Jarga.Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])

    agents = context[:agents] || %{}

    {:ok,
     context
     |> Map.put(:agents, Map.put(agents, agent_name, agent))
     |> Map.put(:agent, agent)}
  end

  step "agent {string} has system prompt {string}", %{args: [agent_name, prompt]} = context do
    user = context[:current_user] || raise "No user logged in. Run 'Given I am logged in' first."

    workspace =
      context[:workspace] || context[:current_workspace] ||
        raise "No workspace. Set :workspace or :current_workspace in a prior step."

    agent =
      Jarga.AgentsFixtures.agent_fixture(user, %{
        name: agent_name,
        system_prompt: prompt,
        enabled: true
      })

    :ok = Jarga.Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])

    agents = context[:agents] || %{}

    {:ok,
     context
     |> Map.put(:agents, Map.put(agents, agent_name, agent))
     |> Map.put(:agent, agent)}
  end

  # ============================================================================
  # AGENT SELECTION STEPS
  # ============================================================================

  step "{string} is selected", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])

    {:ok,
     context
     |> Map.put(:selected_agent, agent)
     |> Map.put(:selected_agent_name, agent_name)}
  end

  step "agent {string} is selected", %{args: [agent_name]} = context do
    existing_agent = get_in(context, [:agents, agent_name])
    user = context[:current_user]
    existing_agents = context[:agents] || %{}

    agent =
      existing_agent ||
        Jarga.AgentsFixtures.agent_fixture(user, %{name: agent_name, enabled: true})

    updated_agents = Map.put(existing_agents, agent_name, agent)

    {:ok,
     context
     |> Map.put(:agents, updated_agents)
     |> Map.put(:selected_agent, agent)}
  end

  step "{string} is my only available agent", %{args: [agent_name]} = context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]

    assert workspace, "Workspace must be created in a prior step"

    # Remove any existing agents from the workspace
    existing_workspace_agents =
      Jarga.Agents.get_workspace_agents_list(workspace.id, user.id)

    Enum.each(existing_workspace_agents, fn existing_agent ->
      Jarga.Agents.sync_agent_workspaces(existing_agent.id, user.id, [])
    end)

    agent = Jarga.AgentsFixtures.agent_fixture(user, %{name: agent_name, enabled: true})
    :ok = Jarga.Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])

    {:ok,
     context
     |> Map.put(:agents, %{agent_name => agent})
     |> Map.put(:agent, agent)
     |> Map.put(:only_agent, agent)}
  end

  step "agent {string} is selected in the chat panel", %{args: [agent_name]} = context do
    user = context[:current_user] || raise "No user logged in. Run 'Given I am logged in' first."

    workspace =
      context[:current_workspace] || context[:workspace] ||
        raise "Workspace must be created in a prior step"

    # Agent must exist - create it in a prior step like:
    #   "Given I have an agent named X" or "Given agent X exists"
    agent =
      get_in(context, [:agents, agent_name]) ||
        raise "Agent '#{agent_name}' not found. Create the agent in a prior step."

    Jarga.Accounts.set_selected_agent_id(user.id, workspace.id, agent.id)

    {:ok, Map.put(context, :selected_agent, agent)}
  end

  step "the chat panel shows agent {string}", %{args: [agent_name]} = context do
    user = context[:current_user]
    workspace = context[:workspace] || context[:current_workspace]
    existing_agents = get_agents(context)

    assert workspace, "Workspace must be set up in a prior step"

    agent = get_or_create_agent(existing_agents, agent_name, user, workspace)
    {:ok, view, html} = live(context[:conn], ~p"/app/workspaces/#{workspace.slug}")

    agent_name_escaped = Phoenix.HTML.html_escape(agent_name) |> Phoenix.HTML.safe_to_string()
    assert html =~ agent_name_escaped, "Expected to see agent '#{agent_name}' in the chat panel"

    {:ok,
     context
     |> Map.put(:expected_agent, agent_name)
     |> Map.put(:agent, agent)
     |> Map.put(:agents, Map.put(existing_agents, agent_name, agent))
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)}
  end

  defp get_or_create_agent(existing_agents, agent_name, user, workspace) do
    case Map.get(existing_agents, agent_name) do
      nil ->
        agent = Jarga.AgentsFixtures.agent_fixture(user, %{name: agent_name, enabled: true})
        :ok = Jarga.Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])
        agent

      existing ->
        existing
    end
  end
end
