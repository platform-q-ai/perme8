defmodule AgentCreateSteps do
  @moduledoc """
  Agent creation step definitions.

  Covers:
  - Form filling and submission
  - Agent creation actions
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.AgentsFixtures

  alias Jarga.Agents

  # ============================================================================
  # FORM FILLING STEPS
  # ============================================================================

  step "I fill in the agent name as {string}", %{args: [name]} = context do
    form_attrs = Map.get(context, :form_attrs, %{})
    {:ok, Map.put(context, :form_attrs, Map.put(form_attrs, "name", name))}
  end

  step "I set the temperature to {string}", %{args: [temp]} = context do
    form_attrs = Map.get(context, :form_attrs, %{})
    {:ok, Map.put(context, :form_attrs, Map.put(form_attrs, "temperature", temp))}
  end

  step "I fill in the following agent details:", context do
    table_data = context.datatable.maps

    form_attrs =
      Enum.reduce(table_data, %{}, fn row, acc ->
        field = row["Field"] |> String.downcase() |> String.replace(" ", "_")
        value = row["Value"]
        Map.put(acc, field, value)
      end)

    Map.put(context, :form_attrs, form_attrs)
  end

  step "I submit the agent form", context do
    form_attrs = Map.get(context, :form_attrs, %{})
    user = context[:current_user]

    params = %{
      "user_id" => user.id,
      "name" => form_attrs["name"] || "",
      "description" => form_attrs["description"],
      "system_prompt" => form_attrs["system_prompt"],
      "model" => form_attrs["model"] || "gpt-4-turbo",
      "temperature" => parse_temperature(form_attrs["temperature"]) || 0.7,
      "visibility" => form_attrs["visibility"] || "PRIVATE"
    }

    result = Agents.create_user_agent(params)
    handle_agent_creation_result(result, context)
  end

  step "I submit the agent edit form", context do
    form_attrs = Map.get(context, :form_attrs, %{})
    user = context[:current_user]
    agent = context[:agent]

    assert agent, "An agent must be set up in a prior step (via 'I click edit on' or similar)"

    result = Agents.update_user_agent(agent.id, user.id, form_attrs)
    handle_agent_update_result(result, context)
  end

  defp handle_agent_update_result({:ok, updated_agent}, context) do
    conn = context[:conn]
    {:ok, view, html} = live(conn, ~p"/app/agents")

    agents = Map.put(context[:agents] || %{}, updated_agent.name, updated_agent)

    {:ok,
     context
     |> Map.put(:agent, updated_agent)
     |> Map.put(:agents, agents)
     |> Map.put(:last_result, {:ok, updated_agent})
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)}
  end

  defp handle_agent_update_result({:error, _} = error, context) do
    {:ok, Map.put(context, :last_result, error)}
  end

  defp handle_agent_creation_result({:ok, agent}, context) do
    conn = context[:conn]
    {:ok, view, html} = live(conn, ~p"/app/agents")

    name_escaped = Phoenix.HTML.html_escape(agent.name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:agent, agent)
     |> Map.put(:agents, Map.put(agents, agent.name, agent))
     |> Map.put(:last_result, {:ok, agent})
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)}
  end

  defp handle_agent_creation_result({:error, changeset}, context) do
    {:ok,
     context
     |> Map.put(:last_result, {:error, changeset})
     |> Map.put(:last_changeset, changeset)}
  end

  step "I submit the agent form without filling in the name", context do
    user = context[:current_user]

    params = %{
      "user_id" => user.id,
      "name" => "",
      "visibility" => "PRIVATE"
    }

    result = Agents.create_user_agent(params)

    {:ok,
     context
     |> Map.put(:last_result, result)
     |> Map.put(:last_changeset, elem(result, 1))}
  end

  step "I create an agent with:", context do
    table_data = context.datatable.maps
    user = context[:current_user]

    form_attrs = parse_form_attrs_from_table(table_data)
    params = build_agent_params(user.id, form_attrs)
    result = Agents.create_user_agent(params)

    handle_create_agent_with_result(result, context)
  end

  defp build_agent_params(user_id, form_attrs) do
    %{
      "user_id" => user_id,
      "name" => form_attrs["name"],
      "input_token_cost" => form_attrs["input_token_cost"],
      "cached_input_token_cost" => form_attrs["cached_input_token_cost"],
      "output_token_cost" => form_attrs["output_token_cost"],
      "cached_output_token_cost" => form_attrs["cached_output_token_cost"]
    }
  end

  defp handle_create_agent_with_result({:ok, agent}, context) do
    agents = Map.get(context, :agents, %{})

    context
    |> Map.put(:agent, agent)
    |> Map.put(:agents, Map.put(agents, agent.name, agent))
    |> Map.put(:last_result, {:ok, agent})
  end

  defp handle_create_agent_with_result({:error, _} = result, context) do
    Map.put(context, :last_result, result)
  end

  # ============================================================================
  # AGENT CREATION ACTIONS
  # ============================================================================

  step "I create an agent named {string}", %{args: [name]} = context do
    user = context[:current_user]
    agent = agent_fixture(user, %{name: name})

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:agent, agent)
     |> Map.put(:agents, Map.put(agents, name, agent))}
  end

  step "I create another agent named {string}", %{args: [name]} = context do
    user = context[:current_user]
    agent = agent_fixture(user, %{name: name})

    agents = Map.get(context, :agents, %{})
    key = "#{name}_#{agent.id}"
    duplicate_agents = Map.get(context, :duplicate_agents, [])

    {:ok,
     context
     |> Map.put(:agents, Map.put(agents, key, agent))
     |> Map.put(:duplicate_agents, [agent | duplicate_agents])}
  end

  step "I create an agent without specifying a model", context do
    user = context[:current_user]
    agent = agent_fixture(user, %{name: "No Model Agent", model: nil})

    {:ok, Map.put(context, :agent, agent)}
  end

  step "I attempt to create an agent with temperature {string}", %{args: [temp]} = context do
    user = context[:current_user]

    params = %{
      "user_id" => user.id,
      "name" => "Test Agent",
      "temperature" => temp
    }

    result = Agents.create_user_agent(params)

    {:ok,
     context
     |> Map.put(:last_result, result)
     |> Map.put(:last_changeset, if(match?({:error, _}, result), do: elem(result, 1), else: nil))}
  end

  # ============================================================================
  # HELPERS
  # ============================================================================

  defp parse_form_attrs_from_table(table_data) do
    Enum.reduce(table_data, %{}, fn row, acc ->
      field = row["Field"] |> String.downcase() |> String.replace(" ", "_")
      value = row["Value"]
      Map.put(acc, field, value)
    end)
  end

  defp parse_temperature(nil), do: nil
  defp parse_temperature(""), do: nil

  defp parse_temperature(temp) when is_binary(temp) do
    case Float.parse(temp) do
      {value, _} -> value
      :error -> temp
    end
  end

  defp parse_temperature(temp), do: temp
end
