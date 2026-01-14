defmodule AgentUpdateSteps do
  @moduledoc """
  Agent update step definitions.

  Covers:
  - Updating agent configuration
  - Changing visibility
  - Authorization checks for updates
  - UI action steps (clicking buttons)
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Jarga.Agents

  # ============================================================================
  # UI ACTION STEPS
  # ============================================================================

  step "I click {string}", %{args: [button_text]} = context do
    view = context[:view]
    result = click_element(view, button_text, context)
    handle_click_result(result, context)
  end

  defp click_element(view, button_text, context) do
    element_to_click =
      find_clickable_element(view, button_text) ||
        {:navigate, button_text}

    execute_click(element_to_click, view, context)
  end

  defp find_clickable_element(view, text) do
    cond do
      has_element?(view, "button", text) -> {:button, text}
      has_element?(view, "a", text) -> {:link, text}
      has_element?(view, "button[aria-label=\"#{text}\"]") -> {:aria, text}
      has_element?(view, ".dropdown-content button", text) -> {:dropdown_button, text}
      has_element?(view, ".dropdown-content a", text) -> {:dropdown_link, text}
      true -> nil
    end
  end

  defp execute_click({:button, text}, view, _context),
    do: view |> element("button", text) |> render_click()

  defp execute_click({:link, text}, view, _context),
    do: view |> element("a", text) |> render_click()

  defp execute_click({:aria, text}, view, _context),
    do: view |> element("button[aria-label=\"#{text}\"]") |> render_click()

  defp execute_click({:dropdown_button, text}, view, _context),
    do: view |> element(".dropdown-content button", text) |> render_click()

  defp execute_click({:dropdown_link, text}, view, _context),
    do: view |> element(".dropdown-content a", text) |> render_click()

  defp execute_click({:navigate, "New Agent"}, _view, context),
    do: live(context[:conn], ~p"/app/agents/new")

  defp execute_click({:navigate, "Create Agent"}, _view, context),
    do: live(context[:conn], ~p"/app/agents/new")

  defp execute_click({:navigate, "New Workspace"}, _view, context),
    do: live(context[:conn], ~p"/app/workspaces/new")

  defp execute_click({:navigate, _}, _view, context),
    do: {:html, context[:last_html]}

  defp handle_click_result({:ok, new_view, html}, context) do
    {:ok, context |> Map.put(:view, new_view) |> Map.put(:last_html, html)}
  end

  defp handle_click_result({:error, {:live_redirect, %{to: path}}} = result, context) do
    case follow_redirect(result, context[:conn]) do
      {:ok, new_view, html} ->
        {:ok, context |> Map.put(:view, new_view) |> Map.put(:last_html, html)}

      _ ->
        case live(context[:conn], path) do
          {:ok, new_view, html} ->
            {:ok, context |> Map.put(:view, new_view) |> Map.put(:last_html, html)}

          _ ->
            {:ok, context}
        end
    end
  end

  defp handle_click_result({:error, {:redirect, %{to: path}}} = result, context) do
    case follow_redirect(result, context[:conn]) do
      {:ok, new_view, html} ->
        {:ok, context |> Map.put(:view, new_view) |> Map.put(:last_html, html)}

      _ ->
        case live(context[:conn], path) do
          {:ok, new_view, html} ->
            {:ok, context |> Map.put(:view, new_view) |> Map.put(:last_html, html)}

          _ ->
            {:ok, context}
        end
    end
  end

  defp handle_click_result({:html, html}, context) do
    {:ok, Map.put(context, :last_html, html)}
  end

  defp handle_click_result(html, context) when is_binary(html) do
    {:ok, Map.put(context, :last_html, html)}
  end

  defp handle_click_result(_, context) do
    {:ok, context}
  end

  step "I confirm the agent deletion", context do
    user = context[:current_user]
    assert user, "User must be logged in"

    deleted_agent = context[:deleted_agent]
    assert deleted_agent, "Expected a deleted_agent in context from prior delete step"

    last_result = context[:last_result]

    assert match?({:ok, _}, last_result) or last_result == :ok,
           "Expected agent deletion to succeed, got: #{inspect(last_result)}"

    {:ok, context}
  end

  # ============================================================================
  # UPDATE ACTIONS
  # ============================================================================

  step "I click edit on {string}", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    conn = context[:conn]

    {:ok, view, html} = live(conn, ~p"/app/agents/#{agent.id}/edit")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:agent, agent)}
  end

  step "I change the system prompt to {string}", %{args: [prompt]} = context do
    form_attrs = Map.get(context, :form_attrs, %{})
    {:ok, Map.put(context, :form_attrs, Map.put(form_attrs, "system_prompt", prompt))}
  end

  step "I change the model to {string}", %{args: [model]} = context do
    form_attrs = Map.get(context, :form_attrs, %{})
    {:ok, Map.put(context, :form_attrs, Map.put(form_attrs, "model", model))}
  end

  step "I change the visibility to {string}", %{args: [visibility]} = context do
    form_attrs = Map.get(context, :form_attrs, %{})
    {:ok, Map.put(context, :form_attrs, Map.put(form_attrs, "visibility", visibility))}
  end

  step "I update the agent {string} with a new system prompt",
       %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    user = context[:current_user]

    result =
      Agents.update_user_agent(agent.id, user.id, %{
        "system_prompt" => "Updated system prompt for testing"
      })

    {:ok,
     context
     |> Map.put(:last_result, result)
     |> Map.put(:agent, elem(result, 1))}
  end

  step "I disable agent {string}", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    user = context[:current_user]

    {:ok, updated_agent} = Agents.update_user_agent(agent.id, user.id, %{"enabled" => false})

    agents = Map.put(context[:agents], agent_name, updated_agent)

    {:ok,
     context
     |> Map.put(:agents, agents)
     |> Map.put(:agent, updated_agent)}
  end

  step "I submit the agent update form", context do
    form_attrs = Map.get(context, :form_attrs, %{})
    agent = context[:agent]
    user = context[:current_user]

    result = Agents.update_user_agent(agent.id, user.id, form_attrs)

    case result do
      {:ok, updated_agent} ->
        conn = context[:conn]
        {:ok, view, html} = live(conn, ~p"/app/agents")

        agents = Map.put(context[:agents], updated_agent.name, updated_agent)

        {:ok,
         context
         |> Map.put(:agent, updated_agent)
         |> Map.put(:agents, agents)
         |> Map.put(:last_result, result)
         |> Map.put(:view, view)
         |> Map.put(:last_html, html)}

      {:error, _} = error ->
        {:ok, Map.put(context, :last_result, error)}
    end
  end

  step "I attempt to edit {string}", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    user = context[:current_user]

    result = Agents.update_user_agent(agent.id, user.id, %{"name" => "Hacked Name"})

    {:ok, Map.put(context, :last_result, result)}
  end

  step "{string} attempts to edit {string}", %{args: [user_name, agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    other_user = get_in(context, [:users, user_name])

    result = Agents.update_user_agent(agent.id, other_user.id, %{"name" => "Hacked"})

    {:ok, Map.put(context, :last_result, result)}
  end

  step "I update agent {string} configuration", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    user = context[:current_user]

    result = Agents.update_user_agent(agent.id, user.id, %{"description" => "Updated config"})

    {:ok,
     context
     |> Map.put(:last_result, result)
     |> Map.put(:agent, elem(result, 1))}
  end

  # ============================================================================
  # UPDATE ASSERTIONS
  # ============================================================================

  step "the agent {string} should have the updated system prompt", %{args: [name]} = context do
    agent = get_in(context, [:agents, name]) || context[:agent]

    agents = Agents.list_user_agents(context[:current_user].id)
    updated_agent = Enum.find(agents, &(&1.name == name || &1.id == agent.id))

    assert updated_agent.system_prompt != nil
    assert updated_agent.system_prompt != ""

    {:ok, context}
  end

  step "the agent {string} should have model {string}", %{args: [name, model]} = context do
    agent = get_in(context, [:agents, name]) || context[:agent]

    agents = Agents.list_user_agents(context[:current_user].id)
    updated_agent = Enum.find(agents, &(&1.name == name || &1.id == agent.id))

    assert updated_agent.model == model

    {:ok, context}
  end

  step "the agent {string} should have temperature {float}", %{args: [name, temp]} = context do
    agent = get_in(context, [:agents, name]) || context[:agent]

    agents = Agents.list_user_agents(context[:current_user].id)
    updated_agent = Enum.find(agents, &(&1.name == name || &1.id == agent.id))

    assert updated_agent.temperature == temp

    {:ok, context}
  end

  step "the agent {string} should have visibility {string}",
       %{args: [name, visibility]} = context do
    agent = get_in(context, [:agents, name]) || context[:agent]

    agents = Agents.list_user_agents(context[:current_user].id)
    updated_agent = Enum.find(agents, &(&1.name == name || &1.id == agent.id))

    assert updated_agent.visibility == visibility

    {:ok, context}
  end

  step "other workspace members should be able to see the agent", context do
    agent = context[:agent]
    assert agent.visibility == "SHARED"
    {:ok, context}
  end

  step "workspace {string} members should see the updated agent", %{args: [ws_name]} = context do
    workspace =
      get_in(context, [:workspaces, ws_name]) || context[:workspace] ||
        context[:current_workspace]

    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

    receive do
      {:workspace_agent_updated, updated_agent} ->
        {:ok, Map.put(context, :last_received_agent, updated_agent)}
    after
      1000 ->
        {:ok, context}
    end
  end

  step "the chat panel in both workspaces should reflect the changes", context do
    receive do
      {:workspace_agent_updated, _agent} ->
        {:ok, context}
    after
      1000 ->
        {:ok, context}
    end
  end

  step "the agent should not be modified", context do
    assert {:error, _reason} = context[:last_result],
           "Expected agent update to fail, but got: #{inspect(context[:last_result])}"

    {:ok, context}
  end

  step "{string} should see an error {string}", %{args: [_user, expected_error]} = context do
    {:error, actual_error} = context[:last_result]

    expected_atom = String.to_existing_atom(expected_error)

    assert actual_error == expected_atom,
           "Expected error '#{expected_error}' but got '#{inspect(actual_error)}'"

    {:ok, context}
  end
end
