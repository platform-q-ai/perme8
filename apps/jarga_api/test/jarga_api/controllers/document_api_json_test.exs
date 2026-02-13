defmodule JargaApi.DocumentApiJSONTest do
  use ExUnit.Case, async: true

  alias JargaApi.DocumentApiJSON
  alias Jarga.Documents.Notes.Domain.ContentHash

  describe "show/1" do
    test "renders document with title, slug, content, visibility, owner, workspace_slug, content_hash" do
      result = %{
        title: "My Document",
        slug: "my-document",
        content: "Some content here",
        visibility: "public",
        owner: "user@example.com",
        workspace_slug: "my-workspace",
        project_slug: nil
      }

      rendered = DocumentApiJSON.show(%{document: result})

      assert rendered[:data][:title] == "My Document"
      assert rendered[:data][:slug] == "my-document"
      assert rendered[:data][:content] == "Some content here"
      assert rendered[:data][:visibility] == "public"
      assert rendered[:data][:owner] == "user@example.com"
      assert rendered[:data][:workspace_slug] == "my-workspace"
      assert rendered[:data][:content_hash] == ContentHash.compute("Some content here")
    end

    test "renders document with project_slug when present" do
      result = %{
        title: "Project Doc",
        slug: "project-doc",
        content: "Content",
        visibility: "private",
        owner: "user@example.com",
        workspace_slug: "my-workspace",
        project_slug: "my-project"
      }

      rendered = DocumentApiJSON.show(%{document: result})

      assert rendered[:data][:project_slug] == "my-project"
      assert rendered[:data][:title] == "Project Doc"
    end

    test "renders document without project_slug when nil" do
      result = %{
        title: "Workspace Doc",
        slug: "workspace-doc",
        content: "Content",
        visibility: "public",
        owner: "user@example.com",
        workspace_slug: "my-workspace",
        project_slug: nil
      }

      rendered = DocumentApiJSON.show(%{document: result})

      refute Map.has_key?(rendered[:data], :project_slug)
    end

    test "content_hash is computed from content when not pre-computed" do
      result = %{
        title: "Doc",
        slug: "doc",
        content: "Hello world",
        visibility: "public",
        owner: "user@example.com",
        workspace_slug: "ws",
        project_slug: nil
      }

      rendered = DocumentApiJSON.show(%{document: result})
      assert rendered[:data][:content_hash] == ContentHash.compute("Hello world")
    end

    test "uses pre-computed content_hash when provided in result" do
      precomputed = ContentHash.compute("the content")

      result = %{
        title: "Doc",
        slug: "doc",
        content: "the content",
        content_hash: precomputed,
        visibility: "public",
        owner: "user@example.com",
        workspace_slug: "ws",
        project_slug: nil
      }

      rendered = DocumentApiJSON.show(%{document: result})
      assert rendered[:data][:content_hash] == precomputed
    end
  end

  describe "created/1" do
    test "renders created document with title, slug, visibility, owner, workspace_slug, content_hash" do
      document = %{
        title: "New Doc",
        slug: "new-doc",
        is_public: false,
        created_by: "some-user-uuid"
      }

      rendered =
        DocumentApiJSON.created(%{
          document: document,
          workspace_slug: "my-workspace",
          project_slug: nil,
          owner_email: "creator@example.com"
        })

      assert rendered[:data][:title] == "New Doc"
      assert rendered[:data][:slug] == "new-doc"
      assert rendered[:data][:visibility] == "private"
      assert rendered[:data][:owner] == "creator@example.com"
      assert rendered[:data][:workspace_slug] == "my-workspace"
      # content is nil for this document, so hash should be hash of empty string
      assert rendered[:data][:content_hash] == ContentHash.compute(nil)
    end

    test "renders created document with public visibility" do
      document = %{
        title: "Public Doc",
        slug: "public-doc",
        is_public: true,
        created_by: "some-user-uuid"
      }

      rendered =
        DocumentApiJSON.created(%{
          document: document,
          workspace_slug: "my-workspace",
          project_slug: nil,
          owner_email: "creator@example.com"
        })

      assert rendered[:data][:visibility] == "public"
    end

    test "renders created document with project_slug when present" do
      document = %{
        title: "Project Doc",
        slug: "project-doc",
        is_public: false,
        created_by: "some-user-uuid"
      }

      rendered =
        DocumentApiJSON.created(%{
          document: document,
          workspace_slug: "my-workspace",
          project_slug: "my-project",
          owner_email: "creator@example.com"
        })

      assert rendered[:data][:project_slug] == "my-project"
    end

    test "renders created document without project_slug when nil" do
      document = %{
        title: "Workspace Doc",
        slug: "workspace-doc",
        is_public: false,
        created_by: "some-user-uuid"
      }

      rendered =
        DocumentApiJSON.created(%{
          document: document,
          workspace_slug: "my-workspace",
          project_slug: nil,
          owner_email: "creator@example.com"
        })

      refute Map.has_key?(rendered[:data], :project_slug)
    end

    test "uses owner_email instead of document.created_by (UUID) for owner field" do
      document = %{
        title: "Doc",
        slug: "doc",
        is_public: false,
        created_by: "a1b2c3d4-uuid-not-email"
      }

      rendered =
        DocumentApiJSON.created(%{
          document: document,
          workspace_slug: "ws",
          project_slug: nil,
          owner_email: "actual@email.com"
        })

      assert rendered[:data][:owner] == "actual@email.com"
      refute rendered[:data][:owner] == "a1b2c3d4-uuid-not-email"
    end

    test "content_hash is computed from document content when present" do
      document = %{
        title: "Doc With Content",
        slug: "doc-with-content",
        is_public: false,
        created_by: "uuid",
        content: "Hello world"
      }

      rendered =
        DocumentApiJSON.created(%{
          document: document,
          workspace_slug: "ws",
          project_slug: nil,
          owner_email: "user@email.com"
        })

      assert rendered[:data][:content_hash] == ContentHash.compute("Hello world")
    end
  end

  describe "updated/1" do
    test "renders full document state including content_hash" do
      result = %{
        title: "Updated Doc",
        slug: "updated-doc",
        content: "Updated content",
        content_hash: ContentHash.compute("Updated content"),
        visibility: "public",
        owner: "user@example.com",
        workspace_slug: "my-workspace",
        project_slug: nil
      }

      rendered = DocumentApiJSON.updated(%{document: result})

      assert rendered[:data][:title] == "Updated Doc"
      assert rendered[:data][:slug] == "updated-doc"
      assert rendered[:data][:content] == "Updated content"
      assert rendered[:data][:content_hash] == ContentHash.compute("Updated content")
      assert rendered[:data][:visibility] == "public"
      assert rendered[:data][:owner] == "user@example.com"
      assert rendered[:data][:workspace_slug] == "my-workspace"
      refute Map.has_key?(rendered[:data], :project_slug)
    end

    test "renders updated document with project_slug" do
      result = %{
        title: "Project Doc",
        slug: "project-doc",
        content: "Content",
        content_hash: ContentHash.compute("Content"),
        visibility: "private",
        owner: "user@example.com",
        workspace_slug: "ws",
        project_slug: "my-project"
      }

      rendered = DocumentApiJSON.updated(%{document: result})
      assert rendered[:data][:project_slug] == "my-project"
    end
  end

  describe "content_conflict/1" do
    test "renders conflict response with current content and hash" do
      conflict_data = %{
        content: "Server's current content",
        content_hash: ContentHash.compute("Server's current content")
      }

      rendered = DocumentApiJSON.content_conflict(%{conflict_data: conflict_data})

      assert rendered[:error] == "content_conflict"
      assert is_binary(rendered[:message])
      assert rendered[:data][:content] == "Server's current content"
      assert rendered[:data][:content_hash] == ContentHash.compute("Server's current content")
    end

    test "renders conflict response with nil content" do
      conflict_data = %{
        content: nil,
        content_hash: ContentHash.compute(nil)
      }

      rendered = DocumentApiJSON.content_conflict(%{conflict_data: conflict_data})

      assert rendered[:data][:content] == nil
      assert rendered[:data][:content_hash] == ContentHash.compute(nil)
    end
  end

  describe "validation_error/1" do
    test "renders changeset errors" do
      changeset =
        {%{}, %{title: :string}}
        |> Ecto.Changeset.cast(%{}, [:title])
        |> Ecto.Changeset.validate_required([:title])

      rendered = DocumentApiJSON.validation_error(%{changeset: changeset})

      assert rendered == %{errors: %{title: ["can't be blank"]}}
    end
  end

  describe "error/1" do
    test "renders error message" do
      rendered = DocumentApiJSON.error(%{message: "Not found"})

      assert rendered == %{error: "Not found"}
    end
  end
end
