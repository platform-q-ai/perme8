defmodule Jarga.Agents.UseCases.PrepareContextTest do
  use ExUnit.Case, async: true

  alias Jarga.Agents.UseCases.PrepareContext

  describe "execute/1" do
    test "extracts context from assigns with full page data" do
      assigns = %{
        current_user: %{email: "user@example.com"},
        current_workspace: %{name: "My Workspace", slug: "my-workspace"},
        current_project: %{name: "My Project"},
        page_title: "Project Plan",
        page: %{slug: "project-plan"},
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

    test "handles missing page content" do
      assigns = %{
        current_workspace: %{name: "Workspace"},
        page_title: "Page"
      }

      assert {:ok, context} = PrepareContext.execute(assigns)

      assert context.document_content == nil
    end

    test "truncates page content to max_content_chars from config" do
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

    test "handles missing page info when workspace slug is missing" do
      assigns = %{
        page_title: "Page",
        page: %{slug: "page"}
        # workspace slug missing
      }

      assert {:ok, context} = PrepareContext.execute(assigns)

      assert context.document_info == nil
    end

    test "handles missing page info when page slug is missing" do
      assigns = %{
        page_title: "Page",
        current_workspace: %{slug: "workspace"}
        # page slug missing
      }

      assert {:ok, context} = PrepareContext.execute(assigns)

      assert context.document_info == nil
    end

    test "builds correct page URL from workspace and page slugs" do
      assigns = %{
        current_workspace: %{slug: "acme-corp"},
        page: %{slug: "roadmap-2024"},
        page_title: "Roadmap 2024"
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
end
