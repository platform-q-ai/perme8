defmodule AgentCreationSteps do
  @moduledoc """
  Cucumber step definitions for Agent Creation scenarios.

  Covers:
  - Creating agents with default settings
  - Creating agents with custom configuration
  - Validation errors
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.AgentsFixtures

  alias Jarga.Agents
  # alias Jarga.Agents.Domain.Entities.Agent  # Not used in this file

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
    # Access data table using dot notation
    table_data = context.datatable.maps

    form_attrs =
      Enum.reduce(table_data, %{}, fn row, acc ->
        field = row["Field"] |> String.downcase() |> String.replace(" ", "_")
        value = row["Value"]
        Map.put(acc, field, value)
      end)

    # Return context directly for data table steps (no {:ok, })
    Map.put(context, :form_attrs, form_attrs)
  end

  step "I submit the agent form", context do
    form_attrs = Map.get(context, :form_attrs, %{})
    user = context[:current_user]
    existing_agent = context[:agent]

    # Check if updating existing agent or creating new
    if existing_agent do
      # Update existing agent
      params = %{
        "name" => form_attrs["name"] || existing_agent.name,
        "description" => form_attrs["description"],
        "system_prompt" => form_attrs["system_prompt"],
        "model" => form_attrs["model"],
        "temperature" => parse_temperature(form_attrs["temperature"]),
        "visibility" => form_attrs["visibility"]
      }

      # Remove nil values to only update fields that were explicitly set
      params = Enum.reject(params, fn {_k, v} -> is_nil(v) end) |> Map.new()

      result = Agents.update_user_agent(existing_agent.id, user.id, params)

      case result do
        {:ok, agent} ->
          conn = context[:conn]
          {:ok, view, html} = live(conn, ~p"/app/agents")

          agents = Map.get(context, :agents, %{})

          {:ok,
           context
           |> Map.put(:agent, agent)
           |> Map.put(:agents, Map.put(agents, agent.name, agent))
           |> Map.put(:last_result, result)
           |> Map.put(:view, view)
           |> Map.put(:last_html, html)}

        {:error, changeset} ->
          {:ok,
           context
           |> Map.put(:last_result, result)
           |> Map.put(:last_changeset, changeset)}
      end
    else
      # Create new agent
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

      case result do
        {:ok, agent} ->
          # Verify agent appears in UI (full-stack test)
          conn = context[:conn]
          {:ok, view, html} = live(conn, ~p"/app/agents")

          # HTML-encode special characters for assertion
          name_escaped = Phoenix.HTML.html_escape(agent.name) |> Phoenix.HTML.safe_to_string()
          assert html =~ name_escaped

          agents = Map.get(context, :agents, %{})

          {:ok,
           context
           |> Map.put(:agent, agent)
           |> Map.put(:agents, Map.put(agents, agent.name, agent))
           |> Map.put(:last_result, result)
           |> Map.put(:view, view)
           |> Map.put(:last_html, html)}

        {:error, changeset} ->
          {:ok,
           context
           |> Map.put(:last_result, result)
           |> Map.put(:last_changeset, changeset)}
      end
    end
  end

  step "I submit the agent form without filling in the name", context do
    user = context[:current_user]

    # Submit with empty name
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
    # Access data table using dot notation
    table_data = context.datatable.maps
    user = context[:current_user]

    form_attrs =
      Enum.reduce(table_data, %{}, fn row, acc ->
        field = row["Field"] |> String.downcase() |> String.replace(" ", "_")
        value = row["Value"]
        Map.put(acc, field, value)
      end)

    params = %{
      "user_id" => user.id,
      "name" => form_attrs["name"],
      "input_token_cost" => form_attrs["input_token_cost"],
      "cached_input_token_cost" => form_attrs["cached_input_token_cost"],
      "output_token_cost" => form_attrs["output_token_cost"],
      "cached_output_token_cost" => form_attrs["cached_output_token_cost"]
    }

    result = Agents.create_user_agent(params)

    case result do
      {:ok, agent} ->
        agents = Map.get(context, :agents, %{})

        context
        |> Map.put(:agent, agent)
        |> Map.put(:agents, Map.put(agents, agent.name, agent))
        |> Map.put(:last_result, result)

      {:error, _} ->
        Map.put(context, :last_result, result)
    end
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

    # Use agent.id as key to avoid overwriting agents with same name
    key = "#{name}_#{agent.id}"

    # Also keep track of duplicate-named agents
    duplicate_agents = Map.get(context, :duplicate_agents, [])

    {:ok,
     context
     |> Map.put(:agents, Map.put(agents, key, agent))
     |> Map.put(:duplicate_agents, [agent | duplicate_agents])}
  end

  step "I create an agent without specifying a model", context do
    user = context[:current_user]
    agent = agent_fixture(user, %{name: "No Model Agent", model: nil})

    {:ok,
     context
     |> Map.put(:agent, agent)}
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
  # CREATION ASSERTIONS
  # ============================================================================

  step "the agent should not be created", context do
    case context[:last_result] do
      {:ok, _} -> flunk("Expected agent creation to fail")
      {:error, _} -> {:ok, context}
    end
  end

  step "the agent should have the configured token costs", context do
    agent = context[:agent]

    assert agent != nil
    assert agent.input_token_cost != nil || agent.output_token_cost != nil

    {:ok, context}
  end

  step "future usage tracking should use these costs", context do
    # Verify that the agent costs are properly set for future usage tracking
    agent = context[:agent]
    assert agent != nil

    # Check if costs are numbers, Decimals, or nil
    assert is_number(agent.input_token_cost) or
             (agent.input_token_cost != nil and agent.input_token_cost.__struct__ == Decimal) or
             agent.input_token_cost == nil,
           "Expected input_token_cost to be a number, Decimal, or nil, got: #{inspect(agent.input_token_cost)}"

    assert is_number(agent.output_token_cost) or
             (agent.output_token_cost != nil and agent.output_token_cost.__struct__ == Decimal) or
             agent.output_token_cost == nil,
           "Expected output_token_cost to be a number, Decimal, or nil, got: #{inspect(agent.output_token_cost)}"

    # Costs should be positive if set
    if agent.input_token_cost do
      cost =
        if agent.input_token_cost.__struct__ == Decimal,
          do: Decimal.to_float(agent.input_token_cost),
          else: agent.input_token_cost

      assert cost > 0
    end

    if agent.output_token_cost do
      cost =
        if agent.output_token_cost.__struct__ == Decimal,
          do: Decimal.to_float(agent.output_token_cost),
          else: agent.output_token_cost

      assert cost > 0
    end

    if agent.output_token_cost do
      cost =
        if agent.output_token_cost.__struct__ == Decimal,
          do: Decimal.to_float(agent.output_token_cost),
          else: agent.output_token_cost

      assert cost > 0
    end

    {:ok, context}
  end

  step "both agents should exist", context do
    agents = Map.get(context, :agents, %{})
    duplicate_agents = Map.get(context, :duplicate_agents, [])

    # Check that we have at least 2 agents total (either via map or duplicate tracking)
    agent_count = length(Map.keys(agents)) + length(duplicate_agents)
    assert agent_count >= 2, "Expected at least 2 agents, got #{agent_count}"

    {:ok, context}
  end

  step "both should have unique IDs", context do
    agents = Map.get(context, :agents, %{})
    agent_list = Map.values(agents)
    ids = Enum.map(agent_list, & &1.id)
    assert length(Enum.uniq(ids)) == length(ids)
    {:ok, context}
  end

  # ============================================================================
  # HELPERS
  # ============================================================================

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
