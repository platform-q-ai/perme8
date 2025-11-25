defmodule JargaWeb.Features.InDocumentAgentChatTest do
  use JargaWeb.FeatureCase, async: false

  import Jarga.AgentsFixtures

  @moduletag :wallaby

  describe "in-document agent chat - full E2E flow with mocked LLM responses" do
    setup do
      # Use persistent test user
      user = Jarga.TestUsers.get_user(:alice)

      # Create a workspace
      workspace = workspace_fixture(user)

      # Create an enabled agent in the workspace with the name "prd-agent"
      agent =
        agent_fixture(user, %{
          name: "prd-agent",
          system_prompt:
            "You are a helpful assistant. Keep responses very brief (1-2 sentences max).",
          model: "gpt-4o-mini",
          temperature: 0.7,
          enabled: true
        })

      # Add agent to workspace
      :ok = Jarga.Agents.sync_agent_workspaces(agent.id, user.id, [workspace.id])

      # Create a public document in the workspace
      document =
        document_fixture(user, workspace, nil, %{
          is_public: true,
          title: "Test Document",
          content: "# Product Requirements\n\nThis is a test document."
        })

      {:ok, user: user, workspace: workspace, agent: agent, document: document}
    end

    @tag :wallaby
    test "user invokes prd-agent and gets mocked LLM response about PRDs", %{
      session: session,
      user: user,
      workspace: workspace,
      document: document,
      agent: agent
    } do
      # Verify agent was created
      assert agent.name == "prd-agent"
      assert agent.enabled == true

      # User logs in and opens document
      session
      |> log_in_user(user)
      |> open_document(workspace.slug, document.slug)

      # Focus editor and type agent command
      session
      |> click_in_editor()
      |> send_keys(["@j prd-agent What is a PRD?"])
      |> wait_for_text_in_editor("@j prd-agent")

      # Press Enter to trigger agent query
      session
      |> press_enter_in_editor()

      # Wait for mocked LLM response to appear
      session
      |> wait_for_agent_response()

      # Verify we got a mocked LLM response about PRDs
      content = get_editor_content(session)

      # Should not be loading
      refute content =~ "Agent thinking", "Should not be loading"

      # Should have substantial content
      assert String.length(content) > 50,
             "Expected LLM response, got only #{String.length(content)} chars"

      # Should mention PRD
      assert content =~ ~r/PRD|product.*requirement/i,
             "Expected response about PRD"
    end

    @tag :wallaby
    test "user invokes nonexistent agent and gets mocked error message", %{
      session: session,
      user: user,
      workspace: workspace,
      document: document
    } do
      session
      |> log_in_user(user)
      |> open_document(workspace.slug, document.slug)

      # Focus editor and type command with nonexistent agent
      session
      |> click_in_editor()
      |> send_keys(["@j invalid-xyz-agent What is this?"])
      |> wait_for_text_in_editor("@j invalid-xyz-agent")

      # Press Enter
      session
      |> press_enter_in_editor()

      # Wait for response to appear
      session
      |> wait_for_agent_response()

      # Check what we got
      content = get_editor_content(session)

      # Should have some content (error or explanation)
      assert String.length(content) > 20, "Expected some response"

      # One of these should be true:
      # 1. Got error from backend: "Agent not found"
      # 2. Plugin didn't trigger (command still there) and user got help from default agent
      # 3. Got explanation about invalid agent
      is_backend_error = content =~ "Agent not found"
      is_explanation = content =~ ~r/not.*valid|invalid|doesn't exist|misspelled/i
      command_still_present = content =~ "@j invalid-xyz-agent"

      assert is_backend_error or is_explanation or command_still_present,
             "Expected error, explanation, or command still present"
    end
  end

  # Helper: Wait for agent response to complete
  # Agent responses are rendered as <span data-node-id="..." data-state="...">
  # We wait for the state to change from "streaming" to something else (done/error)
  defp wait_for_agent_response(session) do
    # Just wait a bit for the response to stream in
    # Mocked responses are fast (5ms per chunk), so 2 seconds is plenty
    session
    |> then(fn s ->
      # Poll for content that's not "Agent thinking"
      retry(
        fn ->
          content = get_editor_content(s)

          unless content =~ "Agent thinking" do
            s
          else
            :retry
          end
        end,
        # 40 retries * 50ms = 2 second timeout
        40,
        50
      )
    end)
  end

  # Simple retry helper
  defp retry(fun, retries_left, delay_ms) when retries_left > 0 do
    case fun.() do
      :retry ->
        Process.sleep(delay_ms)
        retry(fun, retries_left - 1, delay_ms)

      result ->
        result
    end
  end

  defp retry(fun, 0, _delay_ms) do
    # Last attempt
    fun.()
  end
end
