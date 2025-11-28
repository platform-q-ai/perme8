defmodule Jarga.Chat.Application.UseCases.PrepareContextWithAgentTest do
  use ExUnit.Case, async: true

  alias Jarga.Chat.Application.UseCases.PrepareContext

  describe "build_system_message_with_agent/2" do
    test "combines agent's custom system_prompt with document context" do
      # Arrange: Agent with custom prompt
      agent = %{
        id: "agent-123",
        name: "Code Reviewer",
        system_prompt: "You are an expert code reviewer. Focus on security and performance.",
        model: "gpt-4",
        temperature: 0.3
      }

      # Arrange: Document context
      document_context = %{
        current_workspace: "Engineering Team",
        current_project: "Mobile App",
        document_title: "API Documentation",
        document_content: "This document explains our REST API endpoints."
      }

      # Act: Build system message with agent and context
      {:ok, message} = PrepareContext.build_system_message_with_agent(agent, document_context)

      # Assert: Message structure
      assert message.role == "system"

      # Assert: Contains agent's custom prompt
      assert message.content =~ "You are an expert code reviewer"
      assert message.content =~ "Focus on security and performance"

      # Assert: Contains document context
      assert message.content =~ "Engineering Team"
      assert message.content =~ "Mobile App"
      assert message.content =~ "API Documentation"
      assert message.content =~ "This document explains our REST API endpoints"
    end

    test "uses default system message when agent has no system_prompt" do
      # Arrange: Agent without custom prompt
      agent = %{
        id: "agent-456",
        name: "General Assistant",
        system_prompt: nil,
        model: "gpt-4"
      }

      # Arrange: Document context
      document_context = %{
        current_workspace: "Engineering Team",
        document_title: "API Documentation",
        document_content: "REST API guide"
      }

      # Act
      {:ok, message} = PrepareContext.build_system_message_with_agent(agent, document_context)

      # Assert: Uses default Jarga message
      assert message.content =~ "Jarga"
      assert message.content =~ "helpful assistant"

      # Assert: Still includes context
      assert message.content =~ "Engineering Team"
      assert message.content =~ "API Documentation"
      assert message.content =~ "REST API guide"
    end

    test "uses default system message when agent has empty system_prompt" do
      # Arrange: Agent with empty string prompt
      agent = %{
        id: "agent-789",
        name: "General Assistant",
        system_prompt: "",
        model: "gpt-4"
      }

      # Arrange: Document context
      document_context = %{
        current_workspace: "My Workspace"
      }

      # Act
      {:ok, message} = PrepareContext.build_system_message_with_agent(agent, document_context)

      # Assert: Uses default message with context
      assert message.content =~ "Jarga"
      assert message.content =~ "My Workspace"
    end

    test "handles nil agent by using default system message" do
      # Arrange: No agent selected
      agent = nil

      # Arrange: Document context
      document_context = %{
        current_workspace: "Engineering Team",
        document_title: "API Documentation"
      }

      # Act
      {:ok, message} = PrepareContext.build_system_message_with_agent(agent, document_context)

      # Assert: Uses default message
      assert message.content =~ "Jarga"
      assert message.content =~ "Engineering Team"
      assert message.content =~ "API Documentation"
    end

    test "includes all context fields when agent has custom prompt" do
      # Arrange: Agent with custom prompt
      agent = %{
        system_prompt: "You are a specialized assistant."
      }

      # Arrange: Full document context
      document_context = %{
        current_user: "user@example.com",
        current_workspace: "Workspace Name",
        current_project: "Project Name",
        document_title: "Document Title",
        document_content: "Document content here"
      }

      # Act
      {:ok, message} = PrepareContext.build_system_message_with_agent(agent, document_context)

      # Assert: Custom prompt is included
      assert message.content =~ "specialized assistant"

      # Assert: All context fields are included
      assert message.content =~ "Workspace Name"
      assert message.content =~ "Project Name"
      assert message.content =~ "Document Title"
      assert message.content =~ "Document content here"
    end

    test "handles empty document context with custom agent prompt" do
      # Arrange: Agent with custom prompt
      agent = %{
        system_prompt: "You are helpful."
      }

      # Arrange: Empty context
      document_context = %{}

      # Act
      {:ok, message} = PrepareContext.build_system_message_with_agent(agent, document_context)

      # Assert: Only custom prompt is used
      assert message.content =~ "You are helpful"

      # Assert: No context fields mentioned
      refute message.content =~ "workspace"
      refute message.content =~ "project"
    end
  end

  describe "build_system_message_with_agent/2 - document title handling" do
    test "includes document title when agent has custom prompt" do
      # Arrange: Agent with custom prompt
      agent = %{
        system_prompt: "You are a technical writer."
      }

      # Arrange: Context with document title
      document_context = %{
        current_workspace: "Engineering",
        document_title: "API Reference Guide",
        document_content: "Complete REST API documentation"
      }

      # Act
      {:ok, message} = PrepareContext.build_system_message_with_agent(agent, document_context)

      # Assert: Custom prompt is included
      assert message.content =~ "technical writer"

      # Assert: Document title is explicitly mentioned
      assert message.content =~ "API Reference Guide"
      assert message.content =~ "Document title:"

      # Assert: Other context is also included
      assert message.content =~ "Engineering"
      assert message.content =~ "Complete REST API documentation"
    end

    test "includes document title without content" do
      # Arrange: Agent with custom prompt
      agent = %{
        system_prompt: "You are helpful."
      }

      # Arrange: Context with title but no content
      document_context = %{
        document_title: "Meeting Notes",
        current_workspace: "Sales Team"
      }

      # Act
      {:ok, message} = PrepareContext.build_system_message_with_agent(agent, document_context)

      # Assert: Title should be included
      assert message.content =~ "Meeting Notes"
      assert message.content =~ "Document title:"
    end

    test "handles missing document title gracefully" do
      # Arrange: Agent with custom prompt
      agent = %{
        system_prompt: "You are an assistant."
      }

      # Arrange: Context without document title
      document_context = %{
        current_workspace: "Engineering",
        document_content: "Some content"
      }

      # Act
      {:ok, message} = PrepareContext.build_system_message_with_agent(agent, document_context)

      # Assert: Should not include document title line
      refute message.content =~ "Document title:"

      # Assert: Other context is still included
      assert message.content =~ "Engineering"
      assert message.content =~ "Some content"
    end

    test "document title is in correct order in context" do
      # Arrange: Full context
      agent = %{
        system_prompt: "Custom prompt."
      }

      document_context = %{
        current_workspace: "Workspace Name",
        current_project: "Project Name",
        document_title: "Document Title",
        document_content: "Document content"
      }

      # Act
      {:ok, message} = PrepareContext.build_system_message_with_agent(agent, document_context)

      # Assert: Order should be workspace, project, title, content
      content = message.content

      workspace_pos = :binary.match(content, "Workspace Name") |> elem(0)
      project_pos = :binary.match(content, "Project Name") |> elem(0)
      title_pos = :binary.match(content, "Document Title") |> elem(0)
      content_pos = :binary.match(content, "Document content") |> elem(0)

      assert workspace_pos < project_pos, "Workspace should come before project"
      assert project_pos < title_pos, "Project should come before document title"
      assert title_pos < content_pos, "Document title should come before content"
    end
  end
end
