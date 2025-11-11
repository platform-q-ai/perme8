defmodule Jarga.PagesTest do
  use Jarga.DataCase, async: true

  alias Jarga.Documents

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  describe "get_page!/2" do
    test "returns document when it exists and belongs to user" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, page} =
        Documents.create_document(user, workspace.id, %{
          title: "Test Page"
        })

      assert fetched = Documents.get_document!(user, page.id)
      assert fetched.id == page.id
      assert fetched.title == "Test Page"
      assert fetched.user_id == user.id
      assert fetched.created_by == user.id
    end

    test "raises when document doesn't exist" do
      user = user_fixture()

      assert_raise Ecto.NoResultsError, fn ->
        Documents.get_document!(user, Ecto.UUID.generate())
      end
    end

    test "raises when document belongs to different user" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)

      {:ok, page} =
        Documents.create_document(user1, workspace.id, %{
          title: "Private Page"
        })

      assert_raise Ecto.NoResultsError, fn ->
        Documents.get_document!(user2, page.id)
      end
    end
  end

  describe "create_page/3" do
    test "creates document with valid attributes in workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      attrs = %{
        title: "My New Page",
        is_public: false,
        is_pinned: false
      }

      assert {:ok, page} = Documents.create_document(user, workspace.id, attrs)
      assert page.title == "My New Page"
      assert page.user_id == user.id
      assert page.workspace_id == workspace.id
      assert page.project_id == nil
      assert page.created_by == user.id
      assert page.is_public == false
      assert page.is_pinned == false

      # Check that a default note was created via page_component
      page = Repo.preload(page, :document_components)
      assert length(page.document_components) == 1
      [component] = page.document_components
      assert component.component_type == "note"
      assert component.component_id != nil
    end

    test "creates document with valid attributes in project" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      attrs = %{
        title: "Project Page",
        project_id: project.id
      }

      assert {:ok, page} = Documents.create_document(user, workspace.id, attrs)
      assert page.project_id == project.id
      assert page.workspace_id == workspace.id
    end

    test "creates document with minimal attributes" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      attrs = %{title: "Minimal"}

      assert {:ok, page} = Documents.create_document(user, workspace.id, attrs)
      assert page.title == "Minimal"
      assert page.is_public == false
      assert page.is_pinned == false
    end

    test "returns error when title is missing" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      attrs = %{}

      assert {:error, changeset} = Documents.create_document(user, workspace.id, attrs)
      assert "can't be blank" in errors_on(changeset).title
    end

    test "returns error when title is empty" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      attrs = %{title: ""}

      assert {:error, changeset} = Documents.create_document(user, workspace.id, attrs)
      assert "can't be blank" in errors_on(changeset).title
    end

    test "returns error when user is not a member of workspace" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)

      attrs = %{title: "Unauthorized Page"}

      assert {:error, :unauthorized} = Documents.create_document(user, workspace.id, attrs)
    end

    test "returns error when workspace does not exist" do
      user = user_fixture()

      attrs = %{title: "Page"}

      assert {:error, :workspace_not_found} =
               Documents.create_document(user, Ecto.UUID.generate(), attrs)
    end

    test "returns error when project does not belong to workspace" do
      user = user_fixture()
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user)
      project = project_fixture(user, workspace2)

      attrs = %{
        title: "Wrong Project",
        project_id: project.id
      }

      assert {:error, :project_not_in_workspace} =
               Documents.create_document(user, workspace1.id, attrs)
    end
  end

  describe "update_page/3" do
    test "updates document title" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, page} = Documents.create_document(user, workspace.id, %{title: "Original"})

      attrs = %{title: "Updated Title"}

      assert {:ok, updated} = Documents.update_document(user, page.id, attrs)
      assert updated.title == "Updated Title"
      assert updated.id == page.id
    end

    test "updates document pinned status" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, page} = Documents.create_document(user, workspace.id, %{title: "Page"})

      assert {:ok, updated} = Documents.update_document(user, page.id, %{is_pinned: true})
      assert updated.is_pinned == true
    end

    test "updates document public status" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, page} = Documents.create_document(user, workspace.id, %{title: "Page"})

      assert {:ok, updated} = Documents.update_document(user, page.id, %{is_public: true})
      assert updated.is_public == true
    end

    test "returns error when document doesn't exist" do
      user = user_fixture()

      attrs = %{title: "Updated"}

      assert {:error, :document_not_found} =
               Documents.update_document(user, Ecto.UUID.generate(), attrs)
    end

    test "returns error when document belongs to different user" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)

      {:ok, page} = Documents.create_document(user1, workspace.id, %{title: "Private"})

      attrs = %{title: "Hacked"}

      assert {:error, :unauthorized} = Documents.update_document(user2, page.id, attrs)
    end

    test "returns error for invalid title" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, page} = Documents.create_document(user, workspace.id, %{title: "Original"})

      attrs = %{title: ""}

      assert {:error, changeset} = Documents.update_document(user, page.id, attrs)
      assert "can't be blank" in errors_on(changeset).title
    end
  end

  describe "delete_page/2" do
    test "deletes document when it belongs to user" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, page} = Documents.create_document(user, workspace.id, %{title: "To Delete"})

      assert {:ok, deleted} = Documents.delete_document(user, page.id)
      assert deleted.id == page.id

      # Verify page is deleted
      assert_raise Ecto.NoResultsError, fn ->
        Documents.get_document!(user, page.id)
      end
    end

    test "returns error when document doesn't exist" do
      user = user_fixture()

      assert {:error, :document_not_found} = Documents.delete_document(user, Ecto.UUID.generate())
    end

    test "returns error when document belongs to different user" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)

      {:ok, page} = Documents.create_document(user1, workspace.id, %{title: "Protected"})

      assert {:error, :unauthorized} = Documents.delete_document(user2, page.id)
    end

    test "allows admin to delete another user's public document" do
      owner = user_fixture()
      admin = user_fixture()
      workspace = workspace_fixture(owner)

      # Add admin to workspace with admin role
      {:ok, _membership} = invite_and_accept_member(owner, workspace.id, admin.email, :admin)

      # Owner creates a public document
      {:ok, page} =
        Documents.create_document(owner, workspace.id, %{title: "Public Page", is_public: true})

      # Admin can delete the public document
      assert {:ok, deleted} = Documents.delete_document(admin, page.id)
      assert deleted.id == page.id
    end

    test "returns error when admin tries to delete another user's private document" do
      owner = user_fixture()
      admin = user_fixture()
      workspace = workspace_fixture(owner)

      # Add admin to workspace
      {:ok, _membership} = invite_and_accept_member(owner, workspace.id, admin.email, :admin)

      # Owner creates a private document
      {:ok, page} =
        Documents.create_document(owner, workspace.id, %{title: "Private Page", is_public: false})

      # Admin cannot delete private document they don't own
      assert {:error, :forbidden} = Documents.delete_document(admin, page.id)
    end

    test "returns error when member tries to delete another member's public document" do
      owner = user_fixture()
      member1 = user_fixture()
      member2 = user_fixture()
      workspace = workspace_fixture(owner)

      # Add both members to workspace
      {:ok, _membership1} =
        invite_and_accept_member(owner, workspace.id, member1.email, :member)

      {:ok, _membership2} =
        invite_and_accept_member(owner, workspace.id, member2.email, :member)

      # Member1 creates a public document
      {:ok, page} =
        Documents.create_document(member1, workspace.id, %{title: "Member1 Page", is_public: true})

      # Member2 cannot delete Member1's page (only admins can delete others' public documents)
      assert {:error, :forbidden} = Documents.delete_document(member2, page.id)
    end
  end

  describe "list_pages_for_workspace/2" do
    test "returns empty list when workspace has no pages" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert Documents.list_documents_for_workspace(user, workspace.id) == []
    end

    test "returns all pages for workspace belonging to user" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, page1} = Documents.create_document(user, workspace.id, %{title: "Page 1"})
      {:ok, page2} = Documents.create_document(user, workspace.id, %{title: "Page 2"})

      pages = Documents.list_documents_for_workspace(user, workspace.id)

      assert length(pages) == 2
      page_ids = Enum.map(pages, & &1.id)
      assert page1.id in page_ids
      assert page2.id in page_ids
    end

    test "does not return pages from other workspaces" do
      user = user_fixture()
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user)

      {:ok, page1} = Documents.create_document(user, workspace1.id, %{title: "WS1 Page"})
      {:ok, _page2} = Documents.create_document(user, workspace2.id, %{title: "WS2 Page"})

      pages = Documents.list_documents_for_workspace(user, workspace1.id)

      assert length(pages) == 1
      assert hd(pages).id == page1.id
    end

    test "does not return pages from other users" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace1 = workspace_fixture(user1)
      workspace2 = workspace_fixture(user2)

      {:ok, page1} = Documents.create_document(user1, workspace1.id, %{title: "User1 Page"})
      {:ok, page2} = Documents.create_document(user2, workspace2.id, %{title: "User2 Page"})

      # Each user should only see their own pages
      pages_user1 = Documents.list_documents_for_workspace(user1, workspace1.id)
      pages_user2 = Documents.list_documents_for_workspace(user2, workspace2.id)

      assert length(pages_user1) == 1
      assert hd(pages_user1).id == page1.id

      assert length(pages_user2) == 1
      assert hd(pages_user2).id == page2.id
    end

    test "orders pages with pinned first, then by updated_at desc" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      # Create pages
      {:ok, page1} = Documents.create_document(user, workspace.id, %{title: "Page 1"})
      {:ok, page2} = Documents.create_document(user, workspace.id, %{title: "Page 2"})
      {:ok, page3} = Documents.create_document(user, workspace.id, %{title: "Page 3"})
      {:ok, page4} = Documents.create_document(user, workspace.id, %{title: "Page 4"})

      # Manually set updated_at timestamps and pin status to create specific ordering
      # Use raw Ecto queries to bypass the context and set timestamps directly
      base_time = ~U[2025-01-01 12:00:00Z]

      page1
      |> Ecto.Changeset.change(updated_at: DateTime.add(base_time, 0, :second))
      |> Repo.update!()

      page2
      |> Ecto.Changeset.change(is_pinned: true, updated_at: DateTime.add(base_time, 1, :second))
      |> Repo.update!()

      page3
      |> Ecto.Changeset.change(updated_at: DateTime.add(base_time, 2, :second))
      |> Repo.update!()

      page4
      |> Ecto.Changeset.change(is_pinned: true, updated_at: DateTime.add(base_time, 3, :second))
      |> Repo.update!()

      pages = Documents.list_documents_for_workspace(user, workspace.id)

      # Should be ordered: page4 (pinned, newest), page2 (pinned, older), page3 (unpinned, newest), page1 (unpinned, oldest)
      assert length(pages) == 4
      assert Enum.at(pages, 0).id == page4.id
      assert Enum.at(pages, 1).id == page2.id
      assert Enum.at(pages, 2).id == page3.id
      assert Enum.at(pages, 3).id == page1.id
    end
  end

  describe "list_pages_for_project/3" do
    test "returns empty list when project has no pages" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      assert Documents.list_documents_for_project(user, workspace.id, project.id) == []
    end

    test "returns all pages for project belonging to user" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      {:ok, page1} =
        Documents.create_document(user, workspace.id, %{
          title: "Project Page 1",
          project_id: project.id
        })

      {:ok, page2} =
        Documents.create_document(user, workspace.id, %{
          title: "Project Page 2",
          project_id: project.id
        })

      pages = Documents.list_documents_for_project(user, workspace.id, project.id)

      assert length(pages) == 2
      page_ids = Enum.map(pages, & &1.id)
      assert page1.id in page_ids
      assert page2.id in page_ids
    end

    test "does not return pages from other projects" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project1 = project_fixture(user, workspace)
      project2 = project_fixture(user, workspace)

      {:ok, page1} =
        Documents.create_document(user, workspace.id, %{
          title: "P1 Page",
          project_id: project1.id
        })

      {:ok, _page2} =
        Documents.create_document(user, workspace.id, %{
          title: "P2 Page",
          project_id: project2.id
        })

      pages = Documents.list_documents_for_project(user, workspace.id, project1.id)

      assert length(pages) == 1
      assert hd(pages).id == page1.id
    end

    test "orders pages with pinned first, then by updated_at desc" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      # Create pages
      {:ok, page1} =
        Documents.create_document(user, workspace.id, %{
          title: "Page 1",
          project_id: project.id
        })

      {:ok, page2} =
        Documents.create_document(user, workspace.id, %{
          title: "Page 2",
          project_id: project.id
        })

      {:ok, page3} =
        Documents.create_document(user, workspace.id, %{
          title: "Page 3",
          project_id: project.id
        })

      {:ok, page4} =
        Documents.create_document(user, workspace.id, %{
          title: "Page 4",
          project_id: project.id
        })

      # Manually set updated_at timestamps and pin status to create specific ordering
      # Use raw Ecto queries to bypass the context and set timestamps directly
      base_time = ~U[2025-01-01 12:00:00Z]

      page1
      |> Ecto.Changeset.change(updated_at: DateTime.add(base_time, 0, :second))
      |> Repo.update!()

      page2
      |> Ecto.Changeset.change(is_pinned: true, updated_at: DateTime.add(base_time, 1, :second))
      |> Repo.update!()

      page3
      |> Ecto.Changeset.change(updated_at: DateTime.add(base_time, 2, :second))
      |> Repo.update!()

      page4
      |> Ecto.Changeset.change(is_pinned: true, updated_at: DateTime.add(base_time, 3, :second))
      |> Repo.update!()

      pages = Documents.list_documents_for_project(user, workspace.id, project.id)

      # Should be ordered: page4 (pinned, newest), page2 (pinned, older), page3 (unpinned, newest), page1 (unpinned, oldest)
      assert length(pages) == 4
      assert Enum.at(pages, 0).id == page4.id
      assert Enum.at(pages, 1).id == page2.id
      assert Enum.at(pages, 2).id == page3.id
      assert Enum.at(pages, 3).id == page1.id
    end
  end

  describe "document slugs" do
    test "generates slug from title on create" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      attrs = %{title: "My Awesome Page"}

      assert {:ok, page} = Documents.create_document(user, workspace.id, attrs)
      assert page.slug == "my-awesome-page"
    end

    test "generates slug with special characters removed" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      attrs = %{title: "My Page! @#$%"}

      assert {:ok, page} = Documents.create_document(user, workspace.id, attrs)
      assert page.slug == "my-page"
    end

    test "generates slug with consecutive spaces normalized" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      attrs = %{title: "My    Multiple   Spaces"}

      assert {:ok, page} = Documents.create_document(user, workspace.id, attrs)
      assert page.slug == "my-multiple-spaces"
    end

    test "handles slug collisions within same workspace by appending random suffix" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      attrs = %{title: "Duplicate Title"}

      assert {:ok, page1} = Documents.create_document(user, workspace.id, attrs)
      assert page1.slug == "duplicate-title"

      assert {:ok, page2} = Documents.create_document(user, workspace.id, attrs)
      # Should have random suffix appended
      assert page2.slug =~ ~r/^duplicate-title-[a-z0-9]+$/
      assert page2.slug != page1.slug
    end

    test "allows same slug in different workspaces" do
      user = user_fixture()
      workspace1 = workspace_fixture(user, %{name: "Workspace 1"})
      workspace2 = workspace_fixture(user, %{name: "Workspace 2"})
      attrs = %{title: "Same Title"}

      assert {:ok, page1} = Documents.create_document(user, workspace1.id, attrs)
      assert page1.slug == "same-title"

      assert {:ok, page2} = Documents.create_document(user, workspace2.id, attrs)
      # Should have same slug since they're in different workspaces
      assert page2.slug == "same-title"
    end

    test "keeps slug stable when title changes" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      {:ok, page} = Documents.create_document(user, workspace.id, %{title: "Original Title"})

      assert page.slug == "original-title"

      assert {:ok, updated_page} = Documents.update_document(user, page.id, %{title: "New Title"})
      assert updated_page.slug == "original-title"
      assert updated_page.title == "New Title"
    end

    test "keeps original slug when updating title to existing name" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      {:ok, page1} = Documents.create_document(user, workspace.id, %{title: "First Page"})
      {:ok, page2} = Documents.create_document(user, workspace.id, %{title: "Second Page"})

      assert page1.slug == "first-page"
      assert page2.slug == "second-page"

      # Update page2 to have same title as page1
      assert {:ok, updated} = Documents.update_document(user, page2.id, %{title: "First Page"})
      # Slug should remain unchanged
      assert updated.slug == "second-page"
      assert updated.title == "First Page"
    end
  end

  describe "get_page_by_slug!/3" do
    test "returns page when user is owner and slug matches" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      {:ok, page} = Documents.create_document(user, workspace.id, %{title: "My Page"})

      assert fetched = Documents.get_document_by_slug!(user, workspace.id, "my-page")
      assert fetched.id == page.id
      assert fetched.title == page.title
    end

    test "raises when document doesn't exist with that slug" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert_raise Ecto.NoResultsError, fn ->
        Documents.get_document_by_slug!(user, workspace.id, "nonexistent")
      end
    end

    test "raises when user is not the owner" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)
      {:ok, _page} = Documents.create_document(user1, workspace.id, %{title: "Other Page"})

      assert_raise Ecto.NoResultsError, fn ->
        Documents.get_document_by_slug!(user2, workspace.id, "other-page")
      end
    end

    test "raises when page with slug belongs to different workspace" do
      user = user_fixture()
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user)
      {:ok, _page} = Documents.create_document(user, workspace2.id, %{title: "Page"})

      assert_raise Ecto.NoResultsError, fn ->
        Documents.get_document_by_slug!(user, workspace1.id, "page")
      end
    end
  end
end
