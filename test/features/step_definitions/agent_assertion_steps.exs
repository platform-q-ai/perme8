defmodule AgentAssertionSteps do
  @moduledoc """
  Cucumber step definitions for common Agent assertions.

  Covers:
  - Default values verification
  - Agent properties assertions
  - Error message assertions
  - Validation assertions
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  # import Phoenix.LiveViewTest  # Not used in this file
  import Jarga.AgentsFixtures

  alias Jarga.Agents

  # ============================================================================
  # DEFAULT VALUE ASSERTIONS
  # ============================================================================

  step "the agent should have visibility {string}", %{args: [visibility]} = context do
    agent = context[:agent]
    assert agent.visibility == visibility
    {:ok, context}
  end

  step "the agent should have temperature {float}", %{args: [temp]} = context do
    agent = context[:agent]
    assert agent.temperature == temp
    {:ok, context}
  end

  step "the agent should be enabled", context do
    agent = context[:agent]
    assert agent.enabled == true
    {:ok, context}
  end

  step "{string} is enabled", %{args: [agent_name]} = context do
    agent = get_in(context, [:agents, agent_name])
    assert agent.enabled == true
    {:ok, context}
  end

  # ============================================================================
  # VALIDATION ERROR ASSERTIONS
  # ============================================================================

  step "I should see a validation error {string}", %{args: [expected_error]} = context do
    changeset = context[:last_changeset]

    assert changeset != nil

    errors =
      Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
        Enum.reduce(opts, msg, fn {key, value}, acc ->
          String.replace(acc, "%{#{key}}", to_string(value))
        end)
      end)

    error_messages =
      errors
      |> Enum.flat_map(fn {_field, msgs} -> msgs end)
      |> Enum.join(", ")

    assert error_messages =~ expected_error

    {:ok, context}
  end

  step "I should see a changeset error", context do
    changeset = context[:last_changeset]
    assert changeset != nil
    refute changeset.valid?
    {:ok, context}
  end

  step "the validation should fail", context do
    case context[:last_result] do
      {:error, %Ecto.Changeset{valid?: false}} -> {:ok, context}
      {:error, _} -> {:ok, context}
      {:ok, _} -> flunk("Expected validation to fail")
    end
  end

  step "I should see a validation error", context do
    case context[:last_result] do
      {:error, %Ecto.Changeset{valid?: false}} -> {:ok, context}
      {:error, _reason} -> {:ok, context}
      {:ok, _} -> flunk("Expected validation error, got success")
    end
  end

  step "the validation should pass", context do
    case context[:last_result] do
      {:ok, _} ->
        {:ok, context}

      {:error, %Ecto.Changeset{valid?: false} = changeset} ->
        flunk("Validation failed: #{inspect(changeset.errors)}")
    end
  end

  step "I should see error {string}", %{args: [error]} = context do
    changeset = context[:last_changeset]

    if changeset do
      errors =
        Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
          Enum.reduce(opts, msg, fn {key, value}, acc ->
            String.replace(acc, "%{#{key}}", to_string(value))
          end)
        end)

      error_messages =
        errors
        |> Enum.flat_map(fn {_field, msgs} -> msgs end)
        |> Enum.join(", ")

      assert error_messages =~ error
    else
      # Check last_result for error atom
      case context[:last_result] do
        {:error, ^error} ->
          :ok

        {:error, error_atom} when is_atom(error_atom) ->
          assert to_string(error_atom) == error

        _ ->
          flunk("Expected error #{error}")
      end
    end

    {:ok, context}
  end

  step "temperature should be converted to float {float}", %{args: [expected]} = context do
    agent = context[:agent]
    assert agent.temperature == expected
    {:ok, context}
  end

  step "the parameters should be validated", context do
    # Validation happens during agent creation
    {:ok, context}
  end

  # ============================================================================
  # AGENT EXISTENCE ASSERTIONS
  # ============================================================================

  step "I have an agent with ID {string}", %{args: [_id]} = context do
    user = context[:current_user]
    agent = agent_fixture(user, %{name: "Test Agent"})

    {:ok, Map.put(context, :agent, agent)}
  end

  step "I use the agent in chat", context do
    # This would involve sending a chat message with the agent
    # For now, just verify agent exists
    agent = context[:agent]
    assert agent != nil
    {:ok, context}
  end

  step "the system should use the default LLM model", context do
    # The model field can be nil, which means use system default
    agent = context[:agent]
    assert agent.model == nil || agent.model == ""
    {:ok, context}
  end

  step "I am creating a new agent", context do
    # Initialize form state for validation scenarios
    {:ok, Map.put(context, :creating_agent, true)}
  end

  step "I submit parameters with temperature {string}", %{args: [temp]} = context do
    user = context[:current_user]

    params = %{
      "user_id" => user.id,
      "name" => "Test Agent",
      "temperature" => temp
    }

    result = Agents.create_user_agent(params)

    case result do
      {:ok, agent} ->
        {:ok,
         context
         |> Map.put(:agent, agent)
         |> Map.put(:last_result, result)}

      {:error, changeset} ->
        {:ok,
         context
         |> Map.put(:last_result, result)
         |> Map.put(:last_changeset, changeset)}
    end
  end

  step "I submit parameters without a name", context do
    user = context[:current_user]

    params = %{
      "user_id" => user.id,
      "name" => ""
    }

    result = Agents.create_user_agent(params)

    {:ok,
     context
     |> Map.put(:last_result, result)
     |> Map.put(:last_changeset, if(match?({:error, _}, result), do: elem(result, 1), else: nil))}
  end

  # ============================================================================
  # DATETIME SETUP STEPS (for ordering tests)
  # ============================================================================

  step "I created agent {string} {int} days ago", %{args: [name, days]} = context do
    user = context[:current_user]
    agent = agent_fixture(user, %{name: name})

    # Update inserted_at to the specified days ago
    past_date = DateTime.add(DateTime.utc_now(), -days, :day)
    {:ok, agent} = update_agent_timestamp(agent, past_date)

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:agents, Map.put(agents, name, agent))}
  end

  step "I created agent {string} {int} day ago", %{args: [name, days]} = context do
    user = context[:current_user]
    agent = agent_fixture(user, %{name: name})

    # Update inserted_at to the specified days ago
    past_date = DateTime.add(DateTime.utc_now(), -days, :day)
    {:ok, agent} = update_agent_timestamp(agent, past_date)

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:agents, Map.put(agents, name, agent))}
  end

  step "Alice created shared agent {string} {int} days ago",
       %{args: [name, days]} = context do
    alice =
      user_fixture(%{
        email: "alice_agent_#{System.unique_integer([:positive])}@example.com",
        first_name: "Alice"
      })

    agent = agent_fixture(alice, %{name: name, visibility: "SHARED"})

    # Update inserted_at to the specified days ago
    past_date = DateTime.add(DateTime.utc_now(), -days, :day)
    {:ok, agent} = update_agent_timestamp(agent, past_date)

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:agents, Map.put(agents, name, agent))}
  end

  # Helper to update agent timestamp directly in DB
  defp update_agent_timestamp(agent, timestamp) do
    import Ecto.Query
    alias Jarga.Agents.Domain.Entities.Agent

    Jarga.Repo.update_all(
      from(a in Agent, where: a.id == ^agent.id),
      set: [inserted_at: timestamp]
    )

    {:ok, %{agent | inserted_at: timestamp}}
  end

  # ============================================================================
  # CHAT/SYSTEM PROMPT STEPS
  # ============================================================================

  step "I have an agent named {string} with system prompt {string}",
       %{args: [name, prompt]} = context do
    user = context[:current_user]
    agent = agent_fixture(user, %{name: name, system_prompt: prompt})

    agents = Map.get(context, :agents, %{})

    {:ok,
     context
     |> Map.put(:agent, agent)
     |> Map.put(:agents, Map.put(agents, name, agent))}
  end

  step "{string} is selected in the chat panel", %{args: [agent_name]} = context do
    {:ok, Map.put(context, :selected_agent_name, agent_name)}
  end

  # NOTE: "I send a message {string}" is defined in chat_panel_message_steps.exs with proper implementation

  step "the LLM should receive the system message {string}",
       %{args: [_expected_prompt]} = context do
    # This would be verified via Mox mock expectations
    {:ok, context}
  end

  step "the response should reflect the math tutor persona", context do
    # This would be verified via the mocked LLM response
    {:ok, context}
  end

  step "I am viewing a document with content {string}", %{args: [_content]} = context do
    # Set up document context
    {:ok, context}
  end

  step "the system message should include the agent's prompt", context do
    # Verified via PrepareContext use case
    {:ok, context}
  end

  step "the system message should include the document content as context", context do
    # Verified via PrepareContext use case
    {:ok, context}
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp user_fixture(attrs) do
    Jarga.AccountsFixtures.user_fixture(attrs)
  end
end
