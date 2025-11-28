defmodule Jarga.Chat.Application.UseCases.PrepareContextTest do
  use ExUnit.Case, async: true

  alias Jarga.Chat.Application.UseCases.PrepareContext

  describe "execute/1" do
    test "extracts context from assigns with full document data" do
      assigns = %{
        current_user: %{email: "user@example.com"},
        current_workspace: %{name: "My Workspace", slug: "my-workspace"},
        current_project: %{name: "My Project"},
        document_title: "Project Plan",
        document: %{slug: "project-plan"},
        note: %{note_content: %{"markdown" => "# Project Plan\n\nThis is the content"}}
      }

      assert {:ok, context} = PrepareContext.execute(assigns)

      assert context.current_user == "user@example.com"
      assert context.current_workspace == "My Workspace"
      assert context.current_project == "My Project"
      assert context.document_title == "Project Plan"
      assert context.document_content == "# Project Plan\n\nThis is the content"

      assert context.document_info == %{
               document_title: "Project Plan",
               document_url: "/app/workspaces/my-workspace/documents/project-plan"
             }
    end

    test "handles missing user information" do
      assigns = %{}

      assert {:ok, context} = PrepareContext.execute(assigns)

      assert context.current_user == nil
      assert context.current_workspace == nil
      assert context.current_project == nil
    end

    test "handles missing document content" do
      assigns = %{
        current_workspace: %{name: "Workspace"},
        document_title: "Document"
      }

      assert {:ok, context} = PrepareContext.execute(assigns)

      assert context.document_content == nil
    end

    test "truncates document content to max_content_chars from config" do
      # Create content longer than default 3000 chars
      long_content = String.duplicate("a", 4000)

      assigns = %{
        note: %{note_content: %{"markdown" => long_content}}
      }

      assert {:ok, context} = PrepareContext.execute(assigns)

      # Should be truncated to 3000 chars by default
      max_chars = Application.get_env(:jarga, :chat_context)[:max_content_chars] || 3000
      assert String.length(context.document_content) == max_chars
    end

    test "handles empty note content" do
      assigns = %{
        note: %{note_content: %{"markdown" => ""}}
      }

      assert {:ok, context} = PrepareContext.execute(assigns)

      assert context.document_content == nil
    end

    test "handles missing document info when workspace slug is missing" do
      assigns = %{
        document_title: "Document",
        document: %{slug: "document"}
        # workspace slug missing
      }

      assert {:ok, context} = PrepareContext.execute(assigns)

      assert context.document_info == nil
    end

    test "handles missing document info when document slug is missing" do
      assigns = %{
        document_title: "Document",
        current_workspace: %{slug: "workspace"}
        # document slug missing
      }

      assert {:ok, context} = PrepareContext.execute(assigns)

      assert context.document_info == nil
    end

    test "builds correct document URL from workspace and document slugs" do
      assigns = %{
        current_workspace: %{slug: "acme-corp"},
        document: %{slug: "roadmap-2024"},
        document_title: "Roadmap 2024"
      }

      assert {:ok, context} = PrepareContext.execute(assigns)

      assert context.document_info == %{
               document_title: "Roadmap 2024",
               document_url: "/app/workspaces/acme-corp/documents/roadmap-2024"
             }
    end
  end

  describe "build_system_message/1" do
    test "builds system message with all context" do
      context = %{
        current_workspace: "My Workspace",
        current_project: "My Project",
        document_title: "Document Title",
        document_content: "Document content here"
      }

      assert {:ok, message} = PrepareContext.build_system_message(context)

      assert message.role == "system"
      assert message.content =~ "My Workspace"
      assert message.content =~ "My Project"
      assert message.content =~ "Document Title"
      assert message.content =~ "Document content here"
      assert message.content =~ "Jarga"
    end

    test "builds minimal system message when no context provided" do
      context = %{}

      assert {:ok, message} = PrepareContext.build_system_message(context)

      assert message.role == "system"
      assert message.content =~ "helpful assistant"
    end

    test "omits nil values from context message" do
      context = %{
        current_workspace: "Workspace",
        current_project: nil,
        document_title: nil,
        document_content: nil
      }

      assert {:ok, message} = PrepareContext.build_system_message(context)

      assert message.content =~ "Workspace"
      refute message.content =~ "project:"
    end
  end

  describe "execute/1 - document_title field name" do
    test "extracts document title from document_title field (new naming)" do
      assigns = %{
        current_workspace: %{name: "Test Workspace", slug: "test-workspace"},
        document_title: "My Document Title",
        document: %{slug: "my-doc"}
      }

      {:ok, context} = PrepareContext.execute(assigns)

      assert context.document_title == "My Document Title"

      # Should also be in document_info for URL building
      assert context.document_info == %{
               document_title: "My Document Title",
               document_url: "/app/workspaces/test-workspace/documents/my-doc"
             }
    end
  end
end
