defmodule JargaApi.Accounts.Application.UseCases.GetDocumentViaApiTest do
  use Jarga.DataCase, async: true

  alias JargaApi.Accounts.Application.UseCases.GetDocumentViaApi
  alias Identity.Domain.Entities.ApiKey

  defp build_api_key(overrides \\ %{}) do
    defaults = %{
      id: "key-1",
      name: "Test Key",
      hashed_token: "hashed",
      user_id: "user-1",
      workspace_access: ["my-workspace"],
      is_active: true
    }

    ApiKey.new(Map.merge(defaults, overrides))
  end

  defp mock_user, do: %{id: "user-1", email: "test@example.com"}

  defp mock_workspace do
    %{id: "workspace-id", slug: "my-workspace", name: "My Workspace"}
  end

  defp mock_member do
    %{id: "member-id", role: :editor}
  end

  defp mock_document(overrides \\ %{}) do
    defaults = %{
      id: "doc-id",
      title: "My Document",
      slug: "my-document",
      is_public: true,
      user_id: "user-1",
      workspace_id: "workspace-id",
      project_id: nil,
      created_by: "test@example.com",
      document_components: []
    }

    Map.merge(defaults, overrides)
  end

  defp mock_note do
    %{note_content: "Hello, this is document content."}
  end

  defp mock_project do
    %{id: "project-id", slug: "my-project", name: "My Project"}
  end

  defp default_opts(overrides) do
    workspace = mock_workspace()
    member = mock_member()
    document = mock_document()
    note = mock_note()

    defaults = [
      get_workspace_and_member_by_slug: fn _user, _slug -> {:ok, workspace, member} end,
      get_document_by_slug: fn _user, _workspace_id, _slug -> {:ok, document} end,
      get_document_note: fn _document -> note end,
      get_project: fn _user, _workspace_id, _project_id -> {:ok, mock_project()} end
    ]

    Keyword.merge(defaults, overrides)
  end

  describe "execute/5 - success cases" do
    test "returns document data when API key has workspace access" do
      user = mock_user()
      api_key = build_api_key()
      workspace = mock_workspace()
      member = mock_member()
      document = mock_document(%{is_public: true, created_by: "test@example.com"})
      note = mock_note()

      get_workspace_fn = fn ^user, "my-workspace" ->
        {:ok, workspace, member}
      end

      get_document_fn = fn ^user, "workspace-id", "my-document" ->
        {:ok, document}
      end

      get_note_fn = fn ^document ->
        note
      end

      result =
        GetDocumentViaApi.execute(user, api_key, "my-workspace", "my-document",
          get_workspace_and_member_by_slug: get_workspace_fn,
          get_document_by_slug: get_document_fn,
          get_document_note: get_note_fn,
          get_project: fn _, _, _ -> flunk("should not be called") end
        )

      assert {:ok, result_map} = result
      assert result_map.title == "My Document"
      assert result_map.slug == "my-document"
      assert result_map.content == "Hello, this is document content."
      assert result_map.visibility == "public"
      assert result_map.owner == "test@example.com"
      assert result_map.workspace_slug == "my-workspace"
      assert result_map.project_slug == nil
    end

    test "returns document data with project_slug when document has a project" do
      user = mock_user()
      api_key = build_api_key()
      workspace = mock_workspace()
      member = mock_member()
      project = mock_project()

      document =
        mock_document(%{
          project_id: "project-id",
          is_public: false,
          created_by: "owner@example.com"
        })

      note = %{note_content: "Project document content."}

      get_workspace_fn = fn ^user, "my-workspace" ->
        {:ok, workspace, member}
      end

      get_document_fn = fn ^user, "workspace-id", "my-document" ->
        {:ok, document}
      end

      get_note_fn = fn ^document ->
        note
      end

      get_project_fn = fn ^user, "workspace-id", "project-id" ->
        {:ok, project}
      end

      result =
        GetDocumentViaApi.execute(user, api_key, "my-workspace", "my-document",
          get_workspace_and_member_by_slug: get_workspace_fn,
          get_document_by_slug: get_document_fn,
          get_document_note: get_note_fn,
          get_project: get_project_fn
        )

      assert {:ok, result_map} = result
      assert result_map.title == "My Document"
      assert result_map.slug == "my-document"
      assert result_map.content == "Project document content."
      assert result_map.visibility == "private"
      assert result_map.owner == "owner@example.com"
      assert result_map.workspace_slug == "my-workspace"
      assert result_map.project_slug == "my-project"
    end

    test "does not call get_project when document has no project_id" do
      user = mock_user()
      api_key = build_api_key()
      document = mock_document(%{project_id: nil})

      result =
        GetDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "my-document",
          default_opts(
            get_document_by_slug: fn _user, _workspace_id, _slug -> {:ok, document} end,
            get_document_note: fn ^document -> mock_note() end,
            get_project: fn _, _, _ -> flunk("should not be called when project_id is nil") end
          )
        )

      assert {:ok, result_map} = result
      assert result_map.project_slug == nil
    end

    test "returns private visibility for non-public documents" do
      user = mock_user()
      api_key = build_api_key()
      document = mock_document(%{is_public: false})

      result =
        GetDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "my-document",
          default_opts(
            get_document_by_slug: fn _user, _workspace_id, _slug -> {:ok, document} end,
            get_document_note: fn ^document -> mock_note() end
          )
        )

      assert {:ok, result_map} = result
      assert result_map.visibility == "private"
    end
  end

  describe "execute/5 - forbidden cases" do
    test "returns {:error, :forbidden} when API key lacks workspace access" do
      user = mock_user()
      api_key = build_api_key(%{workspace_access: ["other-workspace"]})

      result =
        GetDocumentViaApi.execute(user, api_key, "my-workspace", "my-document",
          get_workspace_and_member_by_slug: fn _, _ -> flunk("should not be called") end,
          get_document_by_slug: fn _, _, _ -> flunk("should not be called") end,
          get_document_note: fn _ -> flunk("should not be called") end,
          get_project: fn _, _, _ -> flunk("should not be called") end
        )

      assert result == {:error, :forbidden}
    end

    test "returns {:error, :forbidden} when workspace_access is nil" do
      user = mock_user()
      api_key = build_api_key(%{workspace_access: nil})

      result =
        GetDocumentViaApi.execute(user, api_key, "my-workspace", "my-document",
          get_workspace_and_member_by_slug: fn _, _ -> flunk("should not be called") end,
          get_document_by_slug: fn _, _, _ -> flunk("should not be called") end,
          get_document_note: fn _ -> flunk("should not be called") end,
          get_project: fn _, _, _ -> flunk("should not be called") end
        )

      assert result == {:error, :forbidden}
    end

    test "returns {:error, :forbidden} when workspace_access is empty list" do
      user = mock_user()
      api_key = build_api_key(%{workspace_access: []})

      result =
        GetDocumentViaApi.execute(user, api_key, "my-workspace", "my-document",
          get_workspace_and_member_by_slug: fn _, _ -> flunk("should not be called") end,
          get_document_by_slug: fn _, _, _ -> flunk("should not be called") end,
          get_document_note: fn _ -> flunk("should not be called") end,
          get_project: fn _, _, _ -> flunk("should not be called") end
        )

      assert result == {:error, :forbidden}
    end
  end

  describe "execute/5 - workspace error cases" do
    test "returns {:error, :workspace_not_found} when workspace doesn't exist" do
      user = mock_user()
      api_key = build_api_key()

      get_workspace_fn = fn _user, _slug -> {:error, :workspace_not_found} end

      result =
        GetDocumentViaApi.execute(user, api_key, "my-workspace", "my-document",
          get_workspace_and_member_by_slug: get_workspace_fn,
          get_document_by_slug: fn _, _, _ -> flunk("should not be called") end,
          get_document_note: fn _ -> flunk("should not be called") end,
          get_project: fn _, _, _ -> flunk("should not be called") end
        )

      assert result == {:error, :workspace_not_found}
    end
  end

  describe "execute/5 - document error cases" do
    test "returns {:error, :document_not_found} when document doesn't exist" do
      user = mock_user()
      api_key = build_api_key()
      workspace = mock_workspace()
      member = mock_member()

      get_workspace_fn = fn _user, _slug -> {:ok, workspace, member} end
      get_document_fn = fn _user, _workspace_id, _slug -> {:error, :document_not_found} end

      result =
        GetDocumentViaApi.execute(user, api_key, "my-workspace", "my-document",
          get_workspace_and_member_by_slug: get_workspace_fn,
          get_document_by_slug: get_document_fn,
          get_document_note: fn _ -> flunk("should not be called") end,
          get_project: fn _, _, _ -> flunk("should not be called") end
        )

      assert result == {:error, :document_not_found}
    end

    test "returns {:error, :document_not_found} for private doc user cannot access" do
      user = mock_user()
      api_key = build_api_key()
      workspace = mock_workspace()
      member = mock_member()

      get_workspace_fn = fn _user, _slug -> {:ok, workspace, member} end

      # get_document_by_slug returns :document_not_found when user can't see private doc
      get_document_fn = fn _user, _workspace_id, _slug -> {:error, :document_not_found} end

      result =
        GetDocumentViaApi.execute(user, api_key, "my-workspace", "private-doc",
          get_workspace_and_member_by_slug: get_workspace_fn,
          get_document_by_slug: get_document_fn,
          get_document_note: fn _ -> flunk("should not be called") end,
          get_project: fn _, _, _ -> flunk("should not be called") end
        )

      assert result == {:error, :document_not_found}
    end
  end
end
