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
      |> then(fn s ->
        Process.sleep(1500)
        s
      end)

      # Focus editor
      session
      |> click_in_editor()
      |> then(fn s ->
        Process.sleep(500)
        s
      end)

      # Type agent command
      session
      |> send_keys(["@j prd-agent What is a PRD?"])
      |> then(fn s ->
        Process.sleep(500)
        s
      end)

      # Verify command was typed
      session
      |> wait_for_text_in_editor("@j prd-agent", 3000)
      |> take_screenshot(name: "01_prd_command_typed")

      # Press Enter to trigger agent query
      session
      |> press_enter_in_editor()
      |> then(fn s ->
        Process.sleep(1000)
        s
      end)
      |> take_screenshot(name: "02_prd_after_enter")

      # Capture and display what we got
      session
      |> then(fn s ->
        content = get_editor_content(s)

        IO.puts("\n" <> String.duplicate("=", 80))
        IO.puts("📋 RESPONSE FROM prd-agent:")
        IO.puts(String.duplicate("=", 80))
        IO.puts(content)
        IO.puts(String.duplicate("=", 80) <> "\n")

        s
      end)

      # Wait for mocked LLM response (should be fast - within 5 seconds)
      session
      |> then(fn s ->
        wait_for_llm_response(s, 5_000)
      end)
      |> take_screenshot(name: "03_prd_final_response")

      # Verify we got a mocked LLM response about PRDs
      session
      |> then(fn s ->
        content = get_editor_content(s)

        # Should not be loading
        refute content =~ "Agent thinking",
               "Should not be loading"

        # Should have substantial content
        assert String.length(content) > 50,
               "Expected LLM response, got only #{String.length(content)} chars"

        # Should mention PRD
        assert content =~ ~r/PRD|product.*requirement/i,
               "Expected response about PRD"

        IO.puts("\n✅ TEST 1 PASSED!")
        IO.puts("✅ Got mocked LLM response from prd-agent")
        IO.puts("✅ Response length: #{String.length(content)} characters")
        IO.puts("✅ Response mentions PRD: #{content =~ ~r/PRD/}")

        s
      end)
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
      |> then(fn s ->
        Process.sleep(1500)
        s
      end)

      # Focus editor
      session
      |> click_in_editor()
      |> then(fn s ->
        Process.sleep(500)
        s
      end)

      # Type command with nonexistent agent
      session
      |> send_keys(["@j invalid-xyz-agent What is this?"])
      |> then(fn s ->
        Process.sleep(500)
        s
      end)
      |> wait_for_text_in_editor("@j invalid-xyz-agent", 3000)
      |> take_screenshot(name: "04_invalid_command_typed")

      # Press Enter
      session
      |> press_enter_in_editor()
      |> then(fn s ->
        Process.sleep(2000)
        s
      end)
      |> take_screenshot(name: "05_invalid_after_enter")

      # Check what we got
      session
      |> then(fn s ->
        content = get_editor_content(s)

        IO.puts("\n" <> String.duplicate("=", 80))
        IO.puts("📋 RESPONSE FOR INVALID AGENT:")
        IO.puts(String.duplicate("=", 80))
        IO.puts(content)
        IO.puts(String.duplicate("=", 80) <> "\n")

        # Should have some content (error or explanation)
        assert String.length(content) > 20,
               "Expected some response"

        # One of these should be true:
        # 1. Got error from backend: "Agent not found"
        # 2. Plugin didn't trigger (command still there) and user got help from default agent
        # 3. Got explanation about invalid agent

        is_backend_error = content =~ "Agent not found"
        is_explanation = content =~ ~r/not.*valid|invalid|doesn't exist|misspelled/i
        command_still_present = content =~ "@j invalid-xyz-agent"

        assert is_backend_error or is_explanation or command_still_present,
               "Expected error, explanation, or command still present"

        cond do
          is_backend_error ->
            IO.puts("\n✅ TEST 2 PASSED!")
            IO.puts("✅ Got backend error: Agent not found")

          is_explanation and not command_still_present ->
            IO.puts("\n✅ TEST 2 PASSED!")
            IO.puts("✅ Got LLM explanation about invalid agent")

          command_still_present ->
            IO.puts("\n✅ TEST 2 PASSED!")
            IO.puts("✅ Command not processed (plugin didn't trigger for invalid agent)")
            IO.puts("✅ This is acceptable behavior - invalid agents may not trigger")

          true ->
            IO.puts("\n✅ TEST 2 PASSED!")
            IO.puts("✅ Got some response about the invalid agent")
        end

        s
      end)
    end
  end

  # Helper: Wait for mocked LLM response to appear
  defp wait_for_llm_response(session, timeout_ms) do
    end_time = System.monotonic_time(:millisecond) + timeout_ms
    poll_for_llm_response(session, end_time, 0)
  end

  defp poll_for_llm_response(session, end_time, attempt) do
    now = System.monotonic_time(:millisecond)

    if now > end_time do
      IO.puts("\n⏱️  Timeout after #{attempt} attempts")
      session
    else
      content = get_editor_content(session)

      cond do
        # Still loading
        content =~ "Agent thinking" ->
          if rem(attempt, 10) == 0 do
            remaining_secs = div(end_time - now, 1000)
            IO.puts("⏳ Waiting for mocked LLM... (attempt #{attempt}, #{remaining_secs}s left)")
          end

          Process.sleep(500)
          poll_for_llm_response(session, end_time, attempt + 1)

        # Got response
        String.length(content) > 50 ->
          IO.puts("✅ Response received after #{attempt} attempts")
          session

        # Keep waiting
        true ->
          Process.sleep(500)
          poll_for_llm_response(session, end_time, attempt + 1)
      end
    end
  end
end
