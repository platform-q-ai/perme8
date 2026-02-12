defmodule JargaApi.Accounts.Application.UseCases.CreateDocumentViaApiTest do
  use Jarga.DataCase, async: true

  alias JargaApi.Accounts.Application.UseCases.CreateDocumentViaApi
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

  defp mock_project do
    %{id: "project-id", slug: "my-project", name: "My Project"}
  end

  describe "execute/5 - success cases" do
    test "creates document when API key has workspace access" do
      user = mock_user()
      api_key = build_api_key()
      workspace = mock_workspace()
      member = mock_member()
      expected_document = %{id: "doc-id", title: "My Doc", slug: "my-doc"}

      get_workspace_fn = fn ^user, "my-workspace" ->
        {:ok, workspace, member}
      end

      create_document_fn = fn ^user, "workspace-id", attrs ->
        assert attrs[:title] == "My Doc"
        {:ok, expected_document}
      end

      result =
        CreateDocumentViaApi.execute(user, api_key, "my-workspace", %{"title" => "My Doc"},
          get_workspace_and_member_by_slug: get_workspace_fn,
          create_document: create_document_fn
        )

      assert {:ok, ^expected_document} = result
    end

    test "creates document with project when project_slug is provided" do
      user = mock_user()
      api_key = build_api_key()
      workspace = mock_workspace()
      member = mock_member()
      project = mock_project()
      expected_document = %{id: "doc-id", title: "My Doc", slug: "my-doc"}

      get_workspace_fn = fn ^user, "my-workspace" ->
        {:ok, workspace, member}
      end

      get_project_fn = fn ^user, "workspace-id", "my-project" ->
        {:ok, project}
      end

      create_document_fn = fn ^user, "workspace-id", attrs ->
        assert attrs[:title] == "Project Doc"
        assert attrs[:project_id] == "project-id"
        {:ok, expected_document}
      end

      result =
        CreateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          %{"title" => "Project Doc", "project_slug" => "my-project"},
          get_workspace_and_member_by_slug: get_workspace_fn,
          create_document: create_document_fn,
          get_project_by_slug: get_project_fn
        )

      assert {:ok, ^expected_document} = result
    end

    test "translates visibility 'public' to is_public: true" do
      user = mock_user()
      api_key = build_api_key()
      workspace = mock_workspace()
      member = mock_member()
      expected_document = %{id: "doc-id", title: "Public Doc", slug: "public-doc"}

      get_workspace_fn = fn _user, _slug -> {:ok, workspace, member} end

      create_document_fn = fn _user, _workspace_id, attrs ->
        assert attrs[:is_public] == true
        refute Map.has_key?(attrs, :visibility)
        {:ok, expected_document}
      end

      result =
        CreateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          %{"title" => "Public Doc", "visibility" => "public"},
          get_workspace_and_member_by_slug: get_workspace_fn,
          create_document: create_document_fn
        )

      assert {:ok, ^expected_document} = result
    end

    test "defaults to is_public: false when no visibility is provided" do
      user = mock_user()
      api_key = build_api_key()
      workspace = mock_workspace()
      member = mock_member()
      expected_document = %{id: "doc-id", title: "Private Doc", slug: "private-doc"}

      get_workspace_fn = fn _user, _slug -> {:ok, workspace, member} end

      create_document_fn = fn _user, _workspace_id, attrs ->
        assert attrs[:is_public] == false
        {:ok, expected_document}
      end

      result =
        CreateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          %{"title" => "Private Doc"},
          get_workspace_and_member_by_slug: get_workspace_fn,
          create_document: create_document_fn
        )

      assert {:ok, ^expected_document} = result
    end
  end

  describe "execute/5 - forbidden cases" do
    test "returns {:error, :forbidden} when API key lacks workspace access" do
      user = mock_user()
      api_key = build_api_key(%{workspace_access: ["other-workspace"]})

      result =
        CreateDocumentViaApi.execute(user, api_key, "my-workspace", %{"title" => "Doc"},
          get_workspace_and_member_by_slug: fn _, _ -> flunk("should not be called") end,
          create_document: fn _, _, _ -> flunk("should not be called") end
        )

      assert result == {:error, :forbidden}
    end

    test "returns {:error, :forbidden} when workspace_access is nil" do
      user = mock_user()
      api_key = build_api_key(%{workspace_access: nil})

      result =
        CreateDocumentViaApi.execute(user, api_key, "my-workspace", %{"title" => "Doc"},
          get_workspace_and_member_by_slug: fn _, _ -> flunk("should not be called") end,
          create_document: fn _, _, _ -> flunk("should not be called") end
        )

      assert result == {:error, :forbidden}
    end

    test "returns {:error, :forbidden} when workspace_access is empty" do
      user = mock_user()
      api_key = build_api_key(%{workspace_access: []})

      result =
        CreateDocumentViaApi.execute(user, api_key, "my-workspace", %{"title" => "Doc"},
          get_workspace_and_member_by_slug: fn _, _ -> flunk("should not be called") end,
          create_document: fn _, _, _ -> flunk("should not be called") end
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
        CreateDocumentViaApi.execute(user, api_key, "my-workspace", %{"title" => "Doc"},
          get_workspace_and_member_by_slug: get_workspace_fn,
          create_document: fn _, _, _ -> flunk("should not be called") end
        )

      assert result == {:error, :workspace_not_found}
    end

    test "returns {:error, :unauthorized} when user is not authorized for workspace" do
      user = mock_user()
      api_key = build_api_key()

      get_workspace_fn = fn _user, _slug -> {:error, :unauthorized} end

      result =
        CreateDocumentViaApi.execute(user, api_key, "my-workspace", %{"title" => "Doc"},
          get_workspace_and_member_by_slug: get_workspace_fn,
          create_document: fn _, _, _ -> flunk("should not be called") end
        )

      assert result == {:error, :unauthorized}
    end
  end

  describe "execute/5 - project error cases" do
    test "returns {:error, :project_not_found} when project doesn't exist" do
      user = mock_user()
      api_key = build_api_key()
      workspace = mock_workspace()
      member = mock_member()

      get_workspace_fn = fn _user, _slug -> {:ok, workspace, member} end

      get_project_fn = fn _user, _workspace_id, _slug -> {:error, :project_not_found} end

      result =
        CreateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          %{"title" => "Doc", "project_slug" => "nonexistent-project"},
          get_workspace_and_member_by_slug: get_workspace_fn,
          create_document: fn _, _, _ -> flunk("should not be called") end,
          get_project_by_slug: get_project_fn
        )

      assert result == {:error, :project_not_found}
    end
  end

  describe "execute/5 - validation error cases" do
    test "passes through changeset errors from create_document" do
      user = mock_user()
      api_key = build_api_key()
      workspace = mock_workspace()
      member = mock_member()

      changeset_error = %Ecto.Changeset{valid?: false, errors: [title: {"can't be blank", []}]}

      get_workspace_fn = fn _user, _slug -> {:ok, workspace, member} end

      create_document_fn = fn _user, _workspace_id, _attrs ->
        {:error, changeset_error}
      end

      result =
        CreateDocumentViaApi.execute(user, api_key, "my-workspace", %{},
          get_workspace_and_member_by_slug: get_workspace_fn,
          create_document: create_document_fn
        )

      assert {:error, ^changeset_error} = result
    end
  end

  describe "execute/5 - content passthrough" do
    test "passes content attribute through to create_document" do
      user = mock_user()
      api_key = build_api_key()
      workspace = mock_workspace()
      member = mock_member()
      expected_document = %{id: "doc-id", title: "Doc With Content", slug: "doc-with-content"}

      get_workspace_fn = fn _user, _slug -> {:ok, workspace, member} end

      create_document_fn = fn _user, _workspace_id, attrs ->
        assert attrs[:content] == "Hello world"
        {:ok, expected_document}
      end

      result =
        CreateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          %{"title" => "Doc With Content", "content" => "Hello world"},
          get_workspace_and_member_by_slug: get_workspace_fn,
          create_document: create_document_fn
        )

      assert {:ok, ^expected_document} = result
    end
  end

  describe "execute/5 - attribute sanitization" do
    test "filters out unknown keys not in the whitelist" do
      user = mock_user()
      api_key = build_api_key()
      workspace = mock_workspace()
      member = mock_member()
      expected_document = %{id: "doc-id", title: "Safe Doc", slug: "safe-doc"}

      get_workspace_fn = fn _user, _slug -> {:ok, workspace, member} end

      create_document_fn = fn _user, _workspace_id, attrs ->
        # Whitelisted keys should be present
        assert attrs[:title] == "Safe Doc"
        # Unknown keys should be filtered out
        refute Map.has_key?(attrs, :admin)
        refute Map.has_key?(attrs, :role)
        refute Map.has_key?(attrs, "unknown_field")
        {:ok, expected_document}
      end

      result =
        CreateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          %{
            "title" => "Safe Doc",
            "admin" => true,
            "role" => "superuser",
            "unknown_field" => "sneaky"
          },
          get_workspace_and_member_by_slug: get_workspace_fn,
          create_document: create_document_fn
        )

      assert {:ok, ^expected_document} = result
    end

    test "does not crash on keys that are not existing atoms" do
      user = mock_user()
      api_key = build_api_key()
      workspace = mock_workspace()
      member = mock_member()
      expected_document = %{id: "doc-id", title: "No Crash", slug: "no-crash"}

      get_workspace_fn = fn _user, _slug -> {:ok, workspace, member} end

      create_document_fn = fn _user, _workspace_id, attrs ->
        assert attrs[:title] == "No Crash"
        {:ok, expected_document}
      end

      # These string keys have never been used as atoms, so String.to_existing_atom
      # would crash. The whitelist approach should handle them safely.
      result =
        CreateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          %{
            "title" => "No Crash",
            "xyzzy_never_an_atom_before_12345" => "value",
            "another_nonexistent_atom_key_98765" => "value"
          },
          get_workspace_and_member_by_slug: get_workspace_fn,
          create_document: create_document_fn
        )

      assert {:ok, ^expected_document} = result
    end
  end
end
