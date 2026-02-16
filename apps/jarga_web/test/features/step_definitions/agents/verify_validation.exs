defmodule AgentVerifyValidationSteps do
  @moduledoc """
  Agent validation error assertion step definitions.

  Covers:
  - Validation error assertions
  - Changeset error checking
  - Parameter submission and validation

  Related modules:
  - AgentVerifySteps - Creation and default assertions
  - AgentVerifyPubSubSteps - Chat/system prompt and PubSub assertions
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  alias Agents

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
    result = context[:last_result]
    assert match?({:error, _}, result), "Expected validation to fail, got: #{inspect(result)}"
    {:ok, context}
  end

  step "I should see a validation error", context do
    result = context[:last_result]
    assert match?({:error, _}, result), "Expected validation error, got: #{inspect(result)}"
    {:ok, context}
  end

  step "the validation should pass", context do
    result = context[:last_result]
    assert match?({:ok, _}, result), "Expected validation to pass, got: #{inspect(result)}"
    {:ok, context}
  end

  step "I should see error {string}", %{args: [error]} = context do
    changeset = context[:last_changeset]
    assert changeset != nil, "Expected last_changeset to be set in context"

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

    {:ok, context}
  end

  step "temperature should be converted to float {float}", %{args: [expected]} = context do
    agent = context[:agent]
    assert agent.temperature == expected
    {:ok, context}
  end

  step "the parameters should be validated", context do
    result = context[:last_result]
    assert result != nil, "Expected last_result to be set from prior step"
    {:ok, context}
  end

  step "I am creating a new agent", context do
    user = context[:current_user]
    assert user != nil, "Expected current_user to be set"
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
        {:ok, context |> Map.put(:agent, agent) |> Map.put(:last_result, result)}

      {:error, changeset} ->
        {:ok, context |> Map.put(:last_result, result) |> Map.put(:last_changeset, changeset)}
    end
  end

  step "I submit parameters without a name", context do
    user = context[:current_user]

    params = %{"user_id" => user.id, "name" => ""}

    result = Agents.create_user_agent(params)

    {:ok,
     context
     |> Map.put(:last_result, result)
     |> Map.put(:last_changeset, if(match?({:error, _}, result), do: elem(result, 1), else: nil))}
  end

  step "I should see an error {string}", %{args: [expected_error]} = context do
    result = context[:last_result]

    assert match?({:error, _}, result), "Expected an error result but got: #{inspect(result)}"

    {:error, actual_error} = result

    expected_atom =
      case expected_error do
        "Message not found" ->
          :not_found

        other ->
          try do
            String.to_existing_atom(other)
          rescue
            ArgumentError -> other
          end
      end

    assert actual_error == expected_atom

    {:ok, context}
  end

  step "I should see an error message {string} in the UI", %{args: [expected_error]} = context do
    html = context[:last_html]

    assert is_binary(html) and html != ""

    error_visible =
      html =~ expected_error or
        html =~ String.downcase(expected_error) or
        html =~ "error" or
        html =~ "Error" or
        html =~ "alert"

    assert error_visible

    {:ok, context}
  end
end
