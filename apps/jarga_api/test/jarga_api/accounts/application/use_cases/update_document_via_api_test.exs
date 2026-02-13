defmodule JargaApi.Accounts.Application.UseCases.UpdateDocumentViaApiTest do
  use Jarga.DataCase, async: true

  alias JargaApi.Accounts.Application.UseCases.UpdateDocumentViaApi
  alias Identity.Domain.Entities.ApiKey
  alias Jarga.Documents.Notes.Domain.ContentHash

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
    Map.merge(
      %{
        id: "doc-id",
        title: "Original Title",
        slug: "original-title",
        is_public: false,
        created_by: "user-1",
        workspace_id: "workspace-id",
        project_id: nil,
        document_components: [
          %{component_type: "note", component_id: "note-1"}
        ]
      },
      overrides
    )
  end

  defp mock_note(overrides \\ %{}) do
    Map.merge(
      %{
        id: "note-1",
        note_content: "original content"
      },
      overrides
    )
  end

  defp base_opts(overrides \\ []) do
    user = mock_user()
    workspace = mock_workspace()
    member = mock_member()
    document = mock_document()
    note = mock_note()

    defaults = [
      get_workspace_and_member_by_slug: fn ^user, "my-workspace" ->
        {:ok, workspace, member}
      end,
      get_document_by_slug: fn ^user, "workspace-id", "original-title" ->
        {:ok, document}
      end,
      get_document_note: fn _doc -> note end,
      update_document: fn _user, "doc-id", attrs -> {:ok, Map.merge(document, attrs)} end,
      update_document_note: fn _doc, attrs -> {:ok, Map.merge(note, attrs)} end
    ]

    Keyword.merge(defaults, overrides)
  end

  describe "execute/6 - success cases" do
    test "updates title only (no content_hash needed)" do
      user = mock_user()
      api_key = build_api_key()
      note = mock_note()

      opts =
        base_opts(
          get_document_note: fn _doc -> note end,
          update_document: fn _user, "doc-id", attrs ->
            assert attrs[:title] == "New Title"
            refute Map.has_key?(attrs, :is_public)
            {:ok, mock_document(%{title: "New Title"})}
          end
        )

      result =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{"title" => "New Title"},
          opts
        )

      assert {:ok, result_map} = result
      assert result_map.title == "New Title"
      assert result_map.content == "original content"
      assert result_map.content_hash == ContentHash.compute("original content")
    end

    test "updates visibility only (no content_hash needed)" do
      user = mock_user()
      api_key = build_api_key()

      opts =
        base_opts(
          update_document: fn _user, "doc-id", attrs ->
            assert attrs[:is_public] == true
            {:ok, mock_document(%{is_public: true})}
          end
        )

      result =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{"visibility" => "public"},
          opts
        )

      assert {:ok, result_map} = result
      assert result_map.visibility == "public"
    end

    test "updates content only with correct content_hash" do
      user = mock_user()
      api_key = build_api_key()
      note = mock_note(%{note_content: "original content"})
      current_hash = ContentHash.compute("original content")

      opts =
        base_opts(
          get_document_note: fn _doc -> note end,
          update_document_note: fn _doc, attrs ->
            assert attrs[:note_content] == "updated content"
            {:ok, mock_note(%{note_content: "updated content"})}
          end
        )

      result =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{"content" => "updated content", "content_hash" => current_hash},
          opts
        )

      assert {:ok, result_map} = result
      # The result fetches note again after update, which returns original mock
      assert is_binary(result_map.content_hash)
    end

    test "updates title + visibility + content together with correct content_hash" do
      user = mock_user()
      api_key = build_api_key()
      note = mock_note(%{note_content: "original content"})
      current_hash = ContentHash.compute("original content")

      opts =
        base_opts(
          get_document_note: fn _doc -> note end,
          update_document: fn _user, "doc-id", attrs ->
            assert attrs[:title] == "New Title"
            assert attrs[:is_public] == true
            {:ok, mock_document(%{title: "New Title", is_public: true})}
          end,
          update_document_note: fn _doc, attrs ->
            assert attrs[:note_content] == "new content"
            {:ok, mock_note(%{note_content: "new content"})}
          end
        )

      result =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{
            "title" => "New Title",
            "visibility" => "public",
            "content" => "new content",
            "content_hash" => current_hash
          },
          opts
        )

      assert {:ok, result_map} = result
      assert result_map.title == "New Title"
      assert result_map.visibility == "public"
    end

    test "omitting visibility doesn't change it" do
      user = mock_user()
      api_key = build_api_key()

      opts =
        base_opts(
          update_document: fn _user, "doc-id", attrs ->
            assert attrs[:title] == "New Title"
            refute Map.has_key?(attrs, :is_public)
            {:ok, mock_document(%{title: "New Title"})}
          end
        )

      result =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{"title" => "New Title"},
          opts
        )

      assert {:ok, result_map} = result
      assert result_map.visibility == "private"
    end

    test "omitting content doesn't touch the note and doesn't require content_hash" do
      user = mock_user()
      api_key = build_api_key()

      opts =
        base_opts(
          update_document_note: fn _doc, _attrs ->
            flunk("update_document_note should not be called")
          end
        )

      result =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{"title" => "New Title"},
          opts
        )

      assert {:ok, _result_map} = result
    end

    test "response includes new content_hash after successful update" do
      user = mock_user()
      api_key = build_api_key()
      note = mock_note(%{note_content: "original content"})

      opts = base_opts(get_document_note: fn _doc -> note end)

      {:ok, result_map} =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{"title" => "Updated"},
          opts
        )

      assert result_map.content_hash == ContentHash.compute("original content")
      assert is_binary(result_map.content_hash)
      assert String.length(result_map.content_hash) == 64
    end

    test "includes owner email and workspace_slug in response" do
      user = mock_user()
      api_key = build_api_key()

      opts = base_opts()

      {:ok, result_map} =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{"title" => "Updated"},
          opts
        )

      assert result_map.owner == "test@example.com"
      assert result_map.workspace_slug == "my-workspace"
      assert result_map.slug == "original-title"
    end
  end

  describe "execute/6 - content hash validation cases" do
    test "content provided without content_hash returns {:error, :content_hash_required}" do
      user = mock_user()
      api_key = build_api_key()
      opts = base_opts()

      result =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{"content" => "new stuff"},
          opts
        )

      assert result == {:error, :content_hash_required}
    end

    test "content provided with wrong content_hash returns {:error, :content_conflict, conflict_data}" do
      user = mock_user()
      api_key = build_api_key()
      note = mock_note(%{note_content: "server content"})

      opts = base_opts(get_document_note: fn _doc -> note end)

      result =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{"content" => "new stuff", "content_hash" => "wrong_hash_value"},
          opts
        )

      assert {:error, :content_conflict, conflict_data} = result
      assert conflict_data.content == "server content"
      assert conflict_data.content_hash == ContentHash.compute("server content")
    end

    test "conflict response includes current content and correct content_hash" do
      user = mock_user()
      api_key = build_api_key()
      note = mock_note(%{note_content: "current server content"})
      expected_hash = ContentHash.compute("current server content")

      opts = base_opts(get_document_note: fn _doc -> note end)

      {:error, :content_conflict, conflict_data} =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{"content" => "my update", "content_hash" => "stale"},
          opts
        )

      assert conflict_data.content == "current server content"
      assert conflict_data.content_hash == expected_hash
    end

    test "hash of nil content (empty document) is predictable and stable" do
      user = mock_user()
      api_key = build_api_key()
      note = mock_note(%{note_content: nil})
      nil_hash = ContentHash.compute(nil)

      opts = base_opts(get_document_note: fn _doc -> note end)

      {:ok, _result} =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{"content" => "first content", "content_hash" => nil_hash},
          opts
        )

      # Should succeed because the hash of nil matches
    end
  end

  describe "execute/6 - forbidden cases" do
    test "returns {:error, :forbidden} when API key lacks workspace access" do
      user = mock_user()
      api_key = build_api_key(%{workspace_access: ["other-workspace"]})

      result =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{"title" => "Doc"},
          get_workspace_and_member_by_slug: fn _, _ -> flunk("should not be called") end,
          get_document_by_slug: fn _, _, _ -> flunk("should not be called") end,
          get_document_note: fn _ -> flunk("should not be called") end,
          update_document: fn _, _, _ -> flunk("should not be called") end,
          update_document_note: fn _, _ -> flunk("should not be called") end
        )

      assert result == {:error, :forbidden}
    end

    test "returns {:error, :forbidden} when workspace_access is nil" do
      user = mock_user()
      api_key = build_api_key(%{workspace_access: nil})

      result =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{"title" => "Doc"},
          []
        )

      assert result == {:error, :forbidden}
    end

    test "returns {:error, :forbidden} when workspace_access is empty" do
      user = mock_user()
      api_key = build_api_key(%{workspace_access: []})

      result =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{"title" => "Doc"},
          []
        )

      assert result == {:error, :forbidden}
    end
  end

  describe "execute/6 - workspace error cases" do
    test "returns {:error, :workspace_not_found} when workspace doesn't exist" do
      user = mock_user()
      api_key = build_api_key()

      opts = [
        get_workspace_and_member_by_slug: fn _user, _slug -> {:error, :workspace_not_found} end,
        get_document_by_slug: fn _, _, _ -> flunk("should not be called") end,
        get_document_note: fn _ -> flunk("should not be called") end,
        update_document: fn _, _, _ -> flunk("should not be called") end,
        update_document_note: fn _, _ -> flunk("should not be called") end
      ]

      result =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{"title" => "Doc"},
          opts
        )

      assert result == {:error, :workspace_not_found}
    end

    test "returns {:error, :unauthorized} when user is not authorized for workspace" do
      user = mock_user()
      api_key = build_api_key()

      opts = [
        get_workspace_and_member_by_slug: fn _user, _slug -> {:error, :unauthorized} end,
        get_document_by_slug: fn _, _, _ -> flunk("should not be called") end,
        get_document_note: fn _ -> flunk("should not be called") end,
        update_document: fn _, _, _ -> flunk("should not be called") end,
        update_document_note: fn _, _ -> flunk("should not be called") end
      ]

      result =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{"title" => "Doc"},
          opts
        )

      assert result == {:error, :unauthorized}
    end
  end

  describe "execute/6 - document error cases" do
    test "returns {:error, :document_not_found} when document doesn't exist" do
      user = mock_user()
      api_key = build_api_key()
      workspace = mock_workspace()
      member = mock_member()

      opts = [
        get_workspace_and_member_by_slug: fn _user, _slug -> {:ok, workspace, member} end,
        get_document_by_slug: fn _user, _ws_id, _slug -> {:error, :document_not_found} end,
        get_document_note: fn _ -> flunk("should not be called") end,
        update_document: fn _, _, _ -> flunk("should not be called") end,
        update_document_note: fn _, _ -> flunk("should not be called") end
      ]

      result =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "nonexistent",
          %{"title" => "Doc"},
          opts
        )

      assert result == {:error, :document_not_found}
    end

    test "returns {:error, :forbidden} when trying to edit another user's private doc" do
      user = mock_user()
      api_key = build_api_key()
      workspace = mock_workspace()
      member = mock_member()

      opts = [
        get_workspace_and_member_by_slug: fn _user, _slug -> {:ok, workspace, member} end,
        get_document_by_slug: fn _user, _ws_id, _slug -> {:error, :forbidden} end,
        get_document_note: fn _ -> flunk("should not be called") end,
        update_document: fn _, _, _ -> flunk("should not be called") end,
        update_document_note: fn _, _ -> flunk("should not be called") end
      ]

      result =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "private-doc",
          %{"title" => "Hacked"},
          opts
        )

      assert result == {:error, :forbidden}
    end
  end

  describe "execute/6 - validation error cases" do
    test "passes through changeset errors from update_document" do
      user = mock_user()
      api_key = build_api_key()

      changeset_error = %Ecto.Changeset{valid?: false, errors: [title: {"can't be blank", []}]}

      opts =
        base_opts(
          update_document: fn _user, _doc_id, _attrs ->
            {:error, changeset_error}
          end
        )

      result =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{"title" => ""},
          opts
        )

      assert {:error, ^changeset_error} = result
    end
  end

  describe "execute/6 - content update error cases" do
    test "note update failure is propagated" do
      user = mock_user()
      api_key = build_api_key()
      note = mock_note(%{note_content: "original"})
      current_hash = ContentHash.compute("original")

      changeset_error =
        %Ecto.Changeset{valid?: false, errors: [note_content: {"is invalid", []}]}

      opts =
        base_opts(
          get_document_note: fn _doc -> note end,
          update_document_note: fn _doc, _attrs ->
            {:error, changeset_error}
          end
        )

      result =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{"content" => "bad content", "content_hash" => current_hash},
          opts
        )

      assert {:error, ^changeset_error} = result
    end
  end

  describe "execute/6 - attribute sanitization" do
    test "unknown keys are filtered out" do
      user = mock_user()
      api_key = build_api_key()

      opts =
        base_opts(
          update_document: fn _user, "doc-id", attrs ->
            assert attrs[:title] == "Safe"
            refute Map.has_key?(attrs, :admin)
            refute Map.has_key?(attrs, :role)
            refute Map.has_key?(attrs, :user_id)
            {:ok, mock_document(%{title: "Safe"})}
          end
        )

      result =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{
            "title" => "Safe",
            "admin" => true,
            "role" => "superuser",
            "user_id" => "injected-id"
          },
          opts
        )

      assert {:ok, _} = result
    end

    test "content_hash is not forwarded to domain update functions" do
      user = mock_user()
      api_key = build_api_key()
      note = mock_note(%{note_content: "original"})
      current_hash = ContentHash.compute("original")

      opts =
        base_opts(
          get_document_note: fn _doc -> note end,
          update_document: fn _user, _doc_id, attrs ->
            refute Map.has_key?(attrs, :content_hash)
            refute Map.has_key?(attrs, "content_hash")
            {:ok, mock_document()}
          end,
          update_document_note: fn _doc, attrs ->
            refute Map.has_key?(attrs, :content_hash)
            assert Map.has_key?(attrs, :note_content)
            {:ok, mock_note()}
          end
        )

      result =
        UpdateDocumentViaApi.execute(
          user,
          api_key,
          "my-workspace",
          "original-title",
          %{
            "title" => "Updated",
            "content" => "new",
            "content_hash" => current_hash
          },
          opts
        )

      assert {:ok, _} = result
    end
  end
end
