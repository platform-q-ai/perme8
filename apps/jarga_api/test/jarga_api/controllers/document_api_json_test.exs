defmodule JargaApi.DocumentApiJSONTest do
  use ExUnit.Case, async: true

  alias JargaApi.DocumentApiJSON

  describe "show/1" do
    test "renders document with title, slug, content, visibility, owner, workspace_slug" do
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

      assert rendered == %{
               data: %{
                 title: "My Document",
                 slug: "my-document",
                 content: "Some content here",
                 visibility: "public",
                 owner: "user@example.com",
                 workspace_slug: "my-workspace"
               }
             }
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
  end

  describe "created/1" do
    test "renders created document with title, slug, visibility, owner (email), workspace_slug" do
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

      assert rendered == %{
               data: %{
                 title: "New Doc",
                 slug: "new-doc",
                 visibility: "private",
                 owner: "creator@example.com",
                 workspace_slug: "my-workspace"
               }
             }
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

      # owner should be the email, not the UUID
      assert rendered[:data][:owner] == "actual@email.com"
      refute rendered[:data][:owner] == "a1b2c3d4-uuid-not-email"
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
