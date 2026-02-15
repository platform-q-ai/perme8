defmodule JargaApi.Accounts.Application.UseCases.GetWorkspaceWithDetailsTest do
  use Jarga.DataCase, async: true

  alias JargaApi.Accounts.Application.UseCases.GetWorkspaceWithDetails
  alias Identity.Domain.Entities.ApiKey
  alias Jarga.Workspaces
  alias Jarga.Documents
  alias Jarga.Projects
  alias Identity.Domain.Entities.Workspace

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.DocumentsFixtures
  import Jarga.ProjectsFixtures

  # Helper to create default context opts for integration tests
  defp default_opts do
    [
      get_workspace_by_slug: &Workspaces.get_workspace_by_slug/2,
      list_documents_for_workspace: &Documents.list_documents_for_workspace/2,
      list_projects_for_workspace: &Projects.list_projects_for_workspace/2
    ]
  end

  describe "execute/4" do
    test "returns workspace with documents and projects when API key has access" do
      user = user_fixture()
      workspace = workspace_fixture(user, %{name: "Product Team"})
      # Create documents - user's own docs and public docs are returned
      _doc1 = document_fixture(user, workspace, nil, %{title: "Product Spec", is_public: true})
      _doc2 = document_fixture(user, workspace, nil, %{title: "Design Doc", is_public: false})
      _project1 = project_fixture(user, workspace, %{name: "Q1 Launch"})
      _project2 = project_fixture(user, workspace, %{name: "Research"})

      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: user.id,
          workspace_access: [workspace.slug],
          is_active: true
        })

      {:ok, result} =
        GetWorkspaceWithDetails.execute(user, api_key, workspace.slug, default_opts())

      # Workspace info (no ID, only slug-based)
      assert result.name == workspace.name
      assert result.slug == workspace.slug
      refute Map.has_key?(result, :id)

      # Documents - user sees their own (public and private)
      assert length(result.documents) == 2
      doc_titles = Enum.map(result.documents, & &1.title)
      assert "Product Spec" in doc_titles
      assert "Design Doc" in doc_titles

      # Document slugs (no IDs)
      assert Enum.all?(result.documents, fn d -> d.slug != nil end)
      assert Enum.all?(result.documents, fn d -> not Map.has_key?(d, :id) end)

      # Projects
      assert length(result.projects) == 2
      project_names = Enum.map(result.projects, & &1.name)
      assert "Q1 Launch" in project_names
      assert "Research" in project_names

      # Project slugs (no IDs)
      assert Enum.all?(result.projects, fn p -> p.slug != nil end)
      assert Enum.all?(result.projects, fn p -> not Map.has_key?(p, :id) end)
    end

    test "returns {:error, :forbidden} when API key lacks workspace access" do
      user = user_fixture()
      workspace = workspace_fixture(user, %{name: "Product Team"})

      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: user.id,
          workspace_access: ["other-workspace"],
          is_active: true
        })

      result = GetWorkspaceWithDetails.execute(user, api_key, workspace.slug, default_opts())

      assert result == {:error, :forbidden}
    end

    test "returns {:error, :workspace_not_found} when workspace doesn't exist" do
      user = user_fixture()

      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: user.id,
          workspace_access: ["non-existent-workspace"],
          is_active: true
        })

      result =
        GetWorkspaceWithDetails.execute(user, api_key, "non-existent-workspace", default_opts())

      assert result == {:error, :workspace_not_found}
    end

    test "returns {:error, :forbidden} when workspace_access is empty" do
      user = user_fixture()
      workspace = workspace_fixture(user, %{name: "Product Team"})

      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: user.id,
          workspace_access: [],
          is_active: true
        })

      result = GetWorkspaceWithDetails.execute(user, api_key, workspace.slug, default_opts())

      assert result == {:error, :forbidden}
    end

    test "includes document and project slugs for subsequent requests" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      document = document_fixture(user, workspace, nil, %{is_public: true})
      project = project_fixture(user, workspace)

      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: user.id,
          workspace_access: [workspace.slug],
          is_active: true
        })

      {:ok, result} =
        GetWorkspaceWithDetails.execute(user, api_key, workspace.slug, default_opts())

      # Only slugs, no IDs
      assert length(result.documents) == 1
      assert hd(result.documents).slug == document.slug
      refute Map.has_key?(hd(result.documents), :id)

      assert length(result.projects) == 1
      assert hd(result.projects).slug == project.slug
      refute Map.has_key?(hd(result.projects), :id)
    end

    test "returns empty documents and projects when workspace has none" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: user.id,
          workspace_access: [workspace.slug],
          is_active: true
        })

      {:ok, result} =
        GetWorkspaceWithDetails.execute(user, api_key, workspace.slug, default_opts())

      assert result.documents == []
      assert result.projects == []
    end

    test "user sees their own documents (both public and private)" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      # Create public and private documents owned by user
      public_doc = document_fixture(user, workspace, nil, %{title: "Public Doc", is_public: true})

      private_doc =
        document_fixture(user, workspace, nil, %{title: "Private Doc", is_public: false})

      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: user.id,
          workspace_access: [workspace.slug],
          is_active: true
        })

      {:ok, result} =
        GetWorkspaceWithDetails.execute(user, api_key, workspace.slug, default_opts())

      # User should see BOTH their public and private documents (identified by slug)
      doc_slugs = Enum.map(result.documents, & &1.slug)
      assert public_doc.slug in doc_slugs
      assert private_doc.slug in doc_slugs
    end

    test "accepts custom functions via opts for testing" do
      user = user_fixture()

      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: user.id,
          workspace_access: ["my-workspace"],
          is_active: true
        })

      mock_get_workspace = fn _user, _slug ->
        {:ok,
         %Workspace{
           id: "workspace-1",
           name: "Mock Workspace",
           slug: "my-workspace"
         }}
      end

      mock_list_documents = fn _user, _workspace_id ->
        [%{title: "Mock Doc", slug: "mock-doc"}]
      end

      mock_list_projects = fn _user, _workspace_id ->
        [%{name: "Mock Project", slug: "mock-project"}]
      end

      {:ok, result} =
        GetWorkspaceWithDetails.execute(user, api_key, "my-workspace",
          get_workspace_by_slug: mock_get_workspace,
          list_documents_for_workspace: mock_list_documents,
          list_projects_for_workspace: mock_list_projects
        )

      assert result.name == "Mock Workspace"
      assert length(result.documents) == 1
      assert length(result.projects) == 1
    end
  end
end
