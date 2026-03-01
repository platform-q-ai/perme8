defmodule Chat.Application.UseCases.PrepareContextTest do
  use ExUnit.Case, async: true

  alias Chat.Application.UseCases.PrepareContext

  describe "execute/1" do
    test "extracts context from assigns with full document data" do
      assigns = %{
        current_user: %{email: "user@example.com"},
        current_workspace: %{name: "My Workspace", slug: "my-workspace"},
        current_project: %{name: "My Project"},
        document_title: "Project Plan",
        document: %{slug: "project-plan"},
        note: %{note_content: "# Project Plan\n\nThis is the content"}
      }

      assert {:ok, context} = PrepareContext.execute(assigns)

      assert context.current_user == "user@example.com"
      assert context.current_workspace == "My Workspace"
      assert context.current_project == "My Project"
      assert context.document_title == "Project Plan"
      assert context.document_content == "# Project Plan\n\nThis is the content"

      assert context.document_info.document_url ==
               "/app/workspaces/my-workspace/documents/project-plan"
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
      assert message.content =~ "Perme8"
    end

    test "builds minimal system message when no context provided" do
      assert {:ok, message} = PrepareContext.build_system_message(%{})
      assert message.content =~ "helpful assistant"
    end
  end
end
