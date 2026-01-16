defmodule Jarga.Documents.Infrastructure.Queries.DocumentQueriesTest do
  use Jarga.DataCase, async: true

  alias Jarga.Documents.Infrastructure.Queries.DocumentQueries
  alias Jarga.Documents
  alias Jarga.Repo

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  describe "base/0" do
    test "returns a queryable for documents" do
      query = DocumentQueries.base()

      assert %Ecto.Query{} = query
    end
  end

  describe "for_user/2" do
    test "filters documents by user" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)
      {:ok, _} = invite_and_accept_member(user1, workspace.id, user2.email, :member)

      {:ok, document1} = Documents.create_document(user1, workspace.id, %{title: "Document 1"})
      {:ok, document2} = Documents.create_document(user2, workspace.id, %{title: "Document 2"})

      results =
        DocumentQueries.base()
        |> DocumentQueries.for_user(user1)
        |> Repo.all()

      document_ids = Enum.map(results, & &1.id)
      assert document1.id in document_ids
      refute document2.id in document_ids
    end
  end

  describe "viewable_by_user/2" do
    test "includes documents owned by user" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, document} = Documents.create_document(user, workspace.id, %{title: "My Document"})

      results =
        DocumentQueries.base()
        |> DocumentQueries.viewable_by_user(user)
        |> Repo.all()

      document_ids = Enum.map(results, & &1.id)
      assert document.id in document_ids
    end

    test "includes public documents in workspaces where user is a member" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      {:ok, document} =
        Documents.create_document(owner, workspace.id, %{title: "Public Document"})

      {:ok, _document} = Documents.update_document(owner, document.id, %{is_public: true})

      results =
        DocumentQueries.base()
        |> DocumentQueries.viewable_by_user(member)
        |> Repo.all()

      document_ids = Enum.map(results, & &1.id)
      assert document.id in document_ids
    end

    test "excludes private documents owned by other users" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)
      {:ok, _} = invite_and_accept_member(user1, workspace.id, user2.email, :member)

      {:ok, document} =
        Documents.create_document(user1, workspace.id, %{title: "Private Document"})

      results =
        DocumentQueries.base()
        |> DocumentQueries.viewable_by_user(user2)
        |> Repo.all()

      document_ids = Enum.map(results, & &1.id)
      refute document.id in document_ids
    end

    test "excludes public documents in workspaces where user is not a member" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)

      {:ok, document} =
        Documents.create_document(user1, workspace.id, %{title: "Public Document"})

      {:ok, _document} = Documents.update_document(user1, document.id, %{is_public: true})

      results =
        DocumentQueries.base()
        |> DocumentQueries.viewable_by_user(user2)
        |> Repo.all()

      document_ids = Enum.map(results, & &1.id)
      refute document.id in document_ids
    end
  end

  describe "for_workspace/2" do
    test "filters documents by workspace" do
      user = user_fixture()
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user)

      {:ok, document1} = Documents.create_document(user, workspace1.id, %{title: "Document 1"})
      {:ok, document2} = Documents.create_document(user, workspace2.id, %{title: "Document 2"})

      results =
        DocumentQueries.base()
        |> DocumentQueries.for_workspace(workspace1.id)
        |> Repo.all()

      document_ids = Enum.map(results, & &1.id)
      assert document1.id in document_ids
      refute document2.id in document_ids
    end
  end

  describe "for_project/2" do
    test "filters documents by project" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project1 = project_fixture(user, workspace)
      project2 = project_fixture(user, workspace)

      {:ok, document1} =
        Documents.create_document(user, workspace.id, %{
          title: "Document 1",
          project_id: project1.id
        })

      {:ok, document2} =
        Documents.create_document(user, workspace.id, %{
          title: "Document 2",
          project_id: project2.id
        })

      results =
        DocumentQueries.base()
        |> DocumentQueries.for_project(project1.id)
        |> Repo.all()

      document_ids = Enum.map(results, & &1.id)
      assert document1.id in document_ids
      refute document2.id in document_ids
    end
  end

  describe "by_id/2" do
    test "filters documents by id" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, document1} = Documents.create_document(user, workspace.id, %{title: "Document 1"})
      {:ok, _document2} = Documents.create_document(user, workspace.id, %{title: "Document 2"})

      result =
        DocumentQueries.base()
        |> DocumentQueries.by_id(document1.id)
        |> Repo.one()

      assert result.id == document1.id
    end

    test "returns nil when document doesn't exist" do
      fake_id = Ecto.UUID.generate()

      result =
        DocumentQueries.base()
        |> DocumentQueries.by_id(fake_id)
        |> Repo.one()

      assert result == nil
    end
  end

  describe "by_slug/2" do
    test "filters documents by slug" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, document1} = Documents.create_document(user, workspace.id, %{title: "Document 1"})
      {:ok, _document2} = Documents.create_document(user, workspace.id, %{title: "Document 2"})

      result =
        DocumentQueries.base()
        |> DocumentQueries.by_slug(document1.slug)
        |> Repo.one()

      assert result.id == document1.id
    end

    test "returns nil when slug doesn't exist" do
      result =
        DocumentQueries.base()
        |> DocumentQueries.by_slug("non-existent-slug")
        |> Repo.one()

      assert result == nil
    end
  end

  describe "ordered/1" do
    test "orders documents with pinned first, then by updated_at descending" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, document1} = Documents.create_document(user, workspace.id, %{title: "Document 1"})
      {:ok, document2} = Documents.create_document(user, workspace.id, %{title: "Document 2"})
      {:ok, document3} = Documents.create_document(user, workspace.id, %{title: "Document 3"})

      # Pin page1
      {:ok, _document1} = Documents.update_document(user, document1.id, %{is_pinned: true})

      results =
        DocumentQueries.base()
        |> DocumentQueries.for_user(user)
        |> DocumentQueries.ordered()
        |> Repo.all()

      document_ids = Enum.map(results, & &1.id)
      # Pinned first
      assert hd(document_ids) == document1.id
      # Remaining two are not pinned
      assert document2.id in document_ids
      assert document3.id in document_ids
    end

    test "orders multiple pinned documents by updated_at descending" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, document1} = Documents.create_document(user, workspace.id, %{title: "Document 1"})
      {:ok, document2} = Documents.create_document(user, workspace.id, %{title: "Document 2"})

      # Pin both
      {:ok, _document1} = Documents.update_document(user, document1.id, %{is_pinned: true})
      {:ok, _document2} = Documents.update_document(user, document2.id, %{is_pinned: true})

      results =
        DocumentQueries.base()
        |> DocumentQueries.for_user(user)
        |> DocumentQueries.ordered()
        |> Repo.all()

      # Both should be pinned
      assert length(results) == 2
      assert Enum.all?(results, & &1.is_pinned)

      # Verify ordering by updated_at descending
      [first, second] = results
      assert DateTime.compare(first.updated_at, second.updated_at) in [:gt, :eq]
    end
  end

  describe "with_components/1" do
    test "preloads document components" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, document} = Documents.create_document(user, workspace.id, %{title: "Document"})

      result =
        DocumentQueries.base()
        |> DocumentQueries.by_id(document.id)
        |> DocumentQueries.with_components()
        |> Repo.one()

      # Components should be loaded (list instead of NotLoaded)
      refute match?(%Ecto.Association.NotLoaded{}, result.document_components)
      assert is_list(result.document_components)
    end
  end

  describe "composable queries" do
    test "can combine multiple filters" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)
      {:ok, _} = invite_and_accept_member(user1, workspace.id, user2.email, :member)
      project = project_fixture(user1, workspace)

      # Create documents in different combinations
      {:ok, document1} =
        Documents.create_document(user1, workspace.id, %{
          title: "Document 1",
          project_id: project.id
        })

      {:ok, _document2} = Documents.create_document(user1, workspace.id, %{title: "Document 2"})

      {:ok, _document3} =
        Documents.create_document(user2, workspace.id, %{
          title: "Document 3",
          project_id: project.id
        })

      results =
        DocumentQueries.base()
        |> DocumentQueries.for_user(user1)
        |> DocumentQueries.for_workspace(workspace.id)
        |> DocumentQueries.for_project(project.id)
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == document1.id
    end
  end
end
