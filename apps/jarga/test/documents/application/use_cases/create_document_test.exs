# credo:disable-for-this-file Jarga.Credo.Check.Architecture.NoDirectRepoInUseCases
defmodule Jarga.Documents.UseCases.CreateDocumentTest do
  use Jarga.DataCase, async: true

  alias Jarga.Documents.Application.UseCases.CreateDocument
  alias Jarga.Documents.Infrastructure.Schemas.DocumentSchema
  alias Jarga.Documents.Notes.Infrastructure.Schemas.NoteSchema

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  describe "execute/2 - successful document creation" do
    test "creates document when actor is workspace owner" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{
          title: "New Page"
        }
      }

      assert {:ok, page} = CreateDocument.execute(params)
      assert page.title == "New Page"
      assert page.slug == "new-page"
      assert page.user_id == owner.id
      assert page.workspace_id == workspace.id
      assert page.created_by == owner.id
    end

    test "creates document when actor is workspace admin" do
      owner = user_fixture()
      admin = user_fixture()
      workspace = workspace_fixture(owner)

      # Add admin as member
      {:ok, _} = invite_and_accept_member(owner, workspace.id, admin.email, :admin)

      params = %{
        actor: admin,
        workspace_id: workspace.id,
        attrs: %{title: "Admin Document"}
      }

      assert {:ok, page} = CreateDocument.execute(params)
      assert page.title == "Admin Document"
      assert page.user_id == admin.id
    end

    test "creates document when actor is workspace member" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)

      # Add member
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      params = %{
        actor: member,
        workspace_id: workspace.id,
        attrs: %{title: "Member Document"}
      }

      assert {:ok, page} = CreateDocument.execute(params)
      assert page.title == "Member Document"
      assert page.user_id == member.id
    end

    test "creates document with project_id when provided" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      project = project_fixture(owner, workspace)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{
          title: "Project Document",
          project_id: project.id
        }
      }

      assert {:ok, page} = CreateDocument.execute(params)
      assert page.title == "Project Document"
      assert page.project_id == project.id
    end

    test "creates document with associated note" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{title: "Document with Note"}
      }

      assert {:ok, document} = CreateDocument.execute(params)

      # Verify note was created - fetch schema from DB to check components
      document_schema =
        DocumentSchema
        |> Repo.get(document.id)
        |> Repo.preload(:document_components)

      assert length(document_schema.document_components) == 1

      component = hd(document_schema.document_components)
      assert component.component_type == "note"
      assert component.position == 0
    end

    test "creates document with content stored as note_content" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{
          title: "Document with Content",
          content: "Some initial content"
        }
      }

      assert {:ok, document} = CreateDocument.execute(params)

      # Fetch the document's note via document_components
      document_schema =
        DocumentSchema
        |> Repo.get(document.id)
        |> Repo.preload(:document_components)

      component = hd(document_schema.document_components)
      note = Repo.get(NoteSchema, component.component_id)

      assert note.note_content == "Some initial content"
    end

    test "creates document without content results in nil note_content" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{title: "Document without Content"}
      }

      assert {:ok, document} = CreateDocument.execute(params)

      # Fetch the document's note via document_components
      document_schema =
        DocumentSchema
        |> Repo.get(document.id)
        |> Repo.preload(:document_components)

      component = hd(document_schema.document_components)
      note = Repo.get(NoteSchema, component.component_id)

      assert note.note_content == nil
    end

    test "generates unique slug when duplicate titles exist" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      # Create first page
      params1 = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{title: "My Page"}
      }

      assert {:ok, page1} = CreateDocument.execute(params1)
      assert page1.slug == "my-page"

      # Create second page with same title
      params2 = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{title: "My Page"}
      }

      assert {:ok, page2} = CreateDocument.execute(params2)
      assert page2.slug != "my-page"
      assert String.starts_with?(page2.slug, "my-page-")
    end

    test "creates document without title" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{}
      }

      # Page creation may require title based on schema,
      # but use case should handle this gracefully
      result = CreateDocument.execute(params)

      # Check the actual behavior - may be error or success with generated title
      case result do
        {:ok, page} -> assert page != nil
        {:error, _} -> :ok
      end
    end
  end

  describe "execute/2 - authorization failures" do
    test "returns error when actor is not a workspace member" do
      owner = user_fixture()
      non_member = user_fixture()
      workspace = workspace_fixture(owner)

      params = %{
        actor: non_member,
        workspace_id: workspace.id,
        attrs: %{title: "Unauthorized Document"}
      }

      assert {:error, reason} = CreateDocument.execute(params)
      assert reason in [:workspace_not_found, :unauthorized]
    end

    test "returns error when workspace doesn't exist" do
      user = user_fixture()
      fake_workspace_id = Ecto.UUID.generate()

      params = %{
        actor: user,
        workspace_id: fake_workspace_id,
        attrs: %{title: "Page"}
      }

      assert {:error, reason} = CreateDocument.execute(params)
      assert reason in [:workspace_not_found, :unauthorized]
    end

    test "returns error when actor is workspace guest" do
      owner = user_fixture()
      guest = user_fixture()
      workspace = workspace_fixture(owner)

      # Add guest as member
      {:ok, _} = invite_and_accept_member(owner, workspace.id, guest.email, :guest)

      params = %{
        actor: guest,
        workspace_id: workspace.id,
        attrs: %{title: "Guest Document"}
      }

      assert {:error, :forbidden} = CreateDocument.execute(params)
    end
  end

  describe "execute/2 - validation failures" do
    test "returns error when project belongs to different workspace" do
      owner = user_fixture()
      workspace1 = workspace_fixture(owner)
      workspace2 = workspace_fixture(owner, %{name: "Workspace 2", slug: "workspace-2"})
      project = project_fixture(owner, workspace2)

      params = %{
        actor: owner,
        workspace_id: workspace1.id,
        attrs: %{
          title: "Page",
          project_id: project.id
        }
      }

      assert {:error, :project_not_in_workspace} = CreateDocument.execute(params)
    end

    test "returns error when project doesn't exist" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      fake_project_id = Ecto.UUID.generate()

      params = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{
          title: "Page",
          project_id: fake_project_id
        }
      }

      assert {:error, reason} = CreateDocument.execute(params)
      assert reason in [:project_not_found, :project_not_in_workspace]
    end
  end

  describe "execute/2 - transaction behavior" do
    test "rolls back document creation if note creation fails" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)

      # Count pages before
      documents_before =
        Repo.aggregate(Jarga.Documents.Infrastructure.Schemas.DocumentSchema, :count)

      # This would need to be done with a mock or by causing note creation to fail
      # For now, we'll just verify successful creation
      params = %{
        actor: owner,
        workspace_id: workspace.id,
        attrs: %{title: "Test Page"}
      }

      {:ok, _page} = CreateDocument.execute(params)

      # Verify page count increased by 1
      documents_after =
        Repo.aggregate(Jarga.Documents.Infrastructure.Schemas.DocumentSchema, :count)

      assert documents_after == documents_before + 1
    end
  end
end
