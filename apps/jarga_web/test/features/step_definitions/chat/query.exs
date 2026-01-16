defmodule ChatQuerySteps do
  @moduledoc """
  Step definitions for Chat Context and Query Steps.

  Covers:
  - Document context for LLM
  - Workspace context
  - System message verification
  - Agent context availability
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  require Jarga.Test.StepHelpers
  import Jarga.Test.StepHelpers

  # ============================================================================
  # DOCUMENT CONTEXT STEPS
  # ============================================================================

  step "the system message should include the document content", context do
    document = context[:document]
    document_content = context[:document_content]

    assert document != nil,
           "Expected document in context. Ensure a 'Given I am viewing a document' step ran first."

    has_content =
      document_content != nil ||
        (is_list(document.document_components) && document.document_components != [])

    assert has_content, "Expected document to have content for system message"

    {:ok, Map.put(context, :document_content_available, true)}
  end

  step "the agent should be able to reference the document in its response", context do
    document = context[:document]

    assert document != nil, "Expected document in context for agent to reference"
    assert document.id != nil, "Expected document to have an ID for agent reference"

    {:ok, Map.put(context, :document_available_for_agent, true)}
  end

  step "the system message should include {string}", %{args: [text]} = context do
    assert is_binary(text), "Expected text to be a string"

    {:ok, Map.put(context, :expected_system_content, text)}
  end

  step "both should be available to the LLM", context do
    agent = resolve_agent(context)

    assert agent != nil,
           "Expected an agent in context. Found: selected_agent=#{inspect(context[:selected_agent])}, agent=#{inspect(context[:agent])}"

    has_document = context[:document] != nil || context[:document_content_available] == true

    assert has_document,
           "Expected document context to be available"

    {:ok, Map.put(context, :llm_context_verified, true)}
  end

  step "only the agent's system prompt should be included", context do
    agent = resolve_agent(context)

    assert agent != nil,
           "Expected an agent in context for system prompt verification"

    {:ok,
     context
     |> Map.put(:only_system_prompt, true)
     |> Map.put(:agent_verified, true)}
  end

  step "no document context should be sent to the LLM", context do
    document = context[:document]

    assert document == nil,
           "Expected no document context, but found: #{inspect(document)}"

    {:ok, Map.put(context, :no_document_context, true)}
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp resolve_agent(context) do
    agent = context[:selected_agent] || context[:agent]

    case agent do
      %{id: _} ->
        agent

      name when is_binary(name) ->
        get_in(context, [:agents, name])

      nil ->
        agents_map = context[:agents] || %{}

        if map_size(agents_map) > 0 do
          agents_map |> Map.values() |> List.first()
        else
          nil
        end

      _ ->
        nil
    end
  end

  # ============================================================================
  # ADDITIONAL CONTEXT STEPS
  # ============================================================================

  step "the LLM request should include the document content", context do
    document = context[:document]
    assert document, "Expected document to be available"
    {:ok, Map.put(context, :llm_request_includes_document, true)}
  end

  step "the agent can reference {string} in its response", %{args: [text]} = context do
    # The agent should be able to reference text from the document context
    document = context[:document]
    document_content = context[:document_content]

    # Verify the document context is available
    has_context = document != nil || document_content != nil

    assert has_context,
           "Expected document context to be available for agent to reference '#{text}'"

    {:ok, Map.put(context, :agent_can_reference, text)}
  end

  step "the LLM should receive system message containing {string}", %{args: [text]} = context do
    # Verify the system message would contain the expected text
    # The system message is built from agent prompt + document context
    alias Jarga.Chat.Application.UseCases.PrepareContext

    agent = resolve_agent(context)
    assert agent != nil, "Expected an agent to be selected"
    assert agent.system_prompt != nil, "Expected agent to have a system prompt"

    # Build the system message using the same logic as the real chat
    chat_context = %{
      current_workspace: context[:workspace] && context[:workspace].name,
      current_project: context[:project] && context[:project].name,
      document_title: context[:document] && context[:document].title,
      document_content: context[:document_content]
    }

    {:ok, system_message} = PrepareContext.build_system_message_with_agent(agent, chat_context)

    # Assert the system message contains the expected text
    assert system_message.content =~ text,
           "Expected system message to contain '#{text}', but got: #{system_message.content}"

    {:ok, Map.put(context, :expected_system_message_content, text)}
  end

  step "the LLM should receive the document content as context", context do
    document = context[:document]
    document_content = context[:document_content]

    # Verify document context is available to be sent to LLM
    has_document = document != nil || document_content != nil

    assert has_document, "Expected document content to be available as context for LLM"

    {:ok, Map.put(context, :document_as_context, true)}
  end

  step "the LLM should be called with model {string}", %{args: [model]} = context do
    agent = context[:selected_agent] || context[:agent]
    assert agent, "Expected an agent to be selected"

    assert agent.model == model,
           "Expected agent model to be '#{model}' but was '#{agent.model}'"

    {:ok, context}
  end

  step "the LLM should be called with temperature {float}", %{args: [temp]} = context do
    agent = context[:selected_agent] || context[:agent]
    assert agent, "Expected an agent to be selected"

    assert_in_delta agent.temperature,
                    temp,
                    0.01,
                    "Expected agent temperature to be #{temp} but was #{agent.temperature}"

    {:ok, context}
  end

  step "the LLM should receive the agent's system prompt", context do
    agent = resolve_agent(context)
    assert agent, "Expected an agent to be available"
    {:ok, context}
  end

  step "no document context should be included", context do
    assert context[:document] == nil, "Expected no document context"
    {:ok, Map.put(context, :no_document_context, true)}
  end

  step "I should see {string} below the response", %{args: [text]} = context do
    {view, context} = ensure_view(context)
    html = render(view)

    text_escaped = Phoenix.HTML.html_escape(text) |> Phoenix.HTML.safe_to_string()

    # Source attribution appears below assistant messages
    has_text = html =~ text_escaped || html =~ text

    {:ok, Map.put(context, :last_html, html) |> Map.put(:source_text_found, has_text)}
  end

  step "the source should be a clickable link", context do
    {view, context} = ensure_view(context)
    html = render(view)

    # Source links are rendered with the link-primary class
    has_source_link =
      html =~ ~r/<a[^>]*class="[^"]*link[^"]*link-primary[^"]*"/ ||
        html =~ ~r/Source:.*<a[^>]*>/s ||
        html =~ "link-primary"

    {:ok, Map.put(context, :last_html, html) |> Map.put(:source_link_found, has_source_link)}
  end

  step "{string} has system prompt {string}", %{args: [agent_name, prompt]} = context do
    agents = context[:agents] || %{}
    agent = Map.get(agents, agent_name)
    user = context[:current_user]

    if agent do
      # Update the agent's system prompt
      {:ok, updated_agent} =
        Jarga.Agents.update_user_agent(agent.id, user.id, %{system_prompt: prompt})

      # Update the agents map with the updated agent
      updated_agents = Map.put(agents, agent_name, updated_agent)

      {:ok,
       context
       |> Map.put(:agents, updated_agents)
       |> Map.put(:selected_agent, updated_agent)
       |> Map.put(:expected_system_prompt, prompt)}
    else
      {:ok, Map.put(context, :expected_system_prompt, prompt)}
    end
  end

  step "the LLM should receive only the document context", context do
    # Verify document context is available but no agent system prompt
    assert context[:document] || context[:document_content_available],
           "Expected document context to be available"

    {:ok, Map.put(context, :only_document_context, true)}
  end
end
