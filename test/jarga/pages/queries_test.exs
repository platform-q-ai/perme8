defmodule Jarga.Pages.QueriesTest do
  use Jarga.DataCase, async: true

  alias Jarga.Pages.Queries
  alias Jarga.Pages
  alias Jarga.Repo

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures

  describe "base/0" do
    test "returns a queryable for pages" do
      query = Queries.base()

      assert %Ecto.Query{} = query
    end
  end

  describe "for_user/2" do
    test "filters pages by user" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)
      {:ok, _} = Jarga.Workspaces.invite_member(user1, workspace.id, user2.email, :member)

      {:ok, page1} = Pages.create_page(user1, workspace.id, %{title: "Page 1"})
      {:ok, page2} = Pages.create_page(user2, workspace.id, %{title: "Page 2"})

      results =
        Queries.base()
        |> Queries.for_user(user1)
        |> Repo.all()

      page_ids = Enum.map(results, & &1.id)
      assert page1.id in page_ids
      refute page2.id in page_ids
    end
  end

  describe "viewable_by_user/2" do
    test "includes pages owned by user" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, page} = Pages.create_page(user, workspace.id, %{title: "My Page"})

      results =
        Queries.base()
        |> Queries.viewable_by_user(user)
        |> Repo.all()

      page_ids = Enum.map(results, & &1.id)
      assert page.id in page_ids
    end

    test "includes public pages in workspaces where user is a member" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)
      {:ok, _} = Jarga.Workspaces.invite_member(owner, workspace.id, member.email, :member)

      {:ok, page} = Pages.create_page(owner, workspace.id, %{title: "Public Page"})
      {:ok, _page} = Pages.update_page(owner, page.id, %{is_public: true})

      results =
        Queries.base()
        |> Queries.viewable_by_user(member)
        |> Repo.all()

      page_ids = Enum.map(results, & &1.id)
      assert page.id in page_ids
    end

    test "excludes private pages owned by other users" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)
      {:ok, _} = Jarga.Workspaces.invite_member(user1, workspace.id, user2.email, :member)

      {:ok, page} = Pages.create_page(user1, workspace.id, %{title: "Private Page"})

      results =
        Queries.base()
        |> Queries.viewable_by_user(user2)
        |> Repo.all()

      page_ids = Enum.map(results, & &1.id)
      refute page.id in page_ids
    end

    test "excludes public pages in workspaces where user is not a member" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)

      {:ok, page} = Pages.create_page(user1, workspace.id, %{title: "Public Page"})
      {:ok, _page} = Pages.update_page(user1, page.id, %{is_public: true})

      results =
        Queries.base()
        |> Queries.viewable_by_user(user2)
        |> Repo.all()

      page_ids = Enum.map(results, & &1.id)
      refute page.id in page_ids
    end
  end

  describe "for_workspace/2" do
    test "filters pages by workspace" do
      user = user_fixture()
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user)

      {:ok, page1} = Pages.create_page(user, workspace1.id, %{title: "Page 1"})
      {:ok, page2} = Pages.create_page(user, workspace2.id, %{title: "Page 2"})

      results =
        Queries.base()
        |> Queries.for_workspace(workspace1.id)
        |> Repo.all()

      page_ids = Enum.map(results, & &1.id)
      assert page1.id in page_ids
      refute page2.id in page_ids
    end
  end

  describe "for_project/2" do
    test "filters pages by project" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project1 = project_fixture(user, workspace)
      project2 = project_fixture(user, workspace)

      {:ok, page1} =
        Pages.create_page(user, workspace.id, %{title: "Page 1", project_id: project1.id})

      {:ok, page2} =
        Pages.create_page(user, workspace.id, %{title: "Page 2", project_id: project2.id})

      results =
        Queries.base()
        |> Queries.for_project(project1.id)
        |> Repo.all()

      page_ids = Enum.map(results, & &1.id)
      assert page1.id in page_ids
      refute page2.id in page_ids
    end
  end

  describe "by_id/2" do
    test "filters pages by id" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, page1} = Pages.create_page(user, workspace.id, %{title: "Page 1"})
      {:ok, _page2} = Pages.create_page(user, workspace.id, %{title: "Page 2"})

      result =
        Queries.base()
        |> Queries.by_id(page1.id)
        |> Repo.one()

      assert result.id == page1.id
    end

    test "returns nil when page doesn't exist" do
      fake_id = Ecto.UUID.generate()

      result =
        Queries.base()
        |> Queries.by_id(fake_id)
        |> Repo.one()

      assert result == nil
    end
  end

  describe "by_slug/2" do
    test "filters pages by slug" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, page1} = Pages.create_page(user, workspace.id, %{title: "Page 1"})
      {:ok, _page2} = Pages.create_page(user, workspace.id, %{title: "Page 2"})

      result =
        Queries.base()
        |> Queries.by_slug(page1.slug)
        |> Repo.one()

      assert result.id == page1.id
    end

    test "returns nil when slug doesn't exist" do
      result =
        Queries.base()
        |> Queries.by_slug("non-existent-slug")
        |> Repo.one()

      assert result == nil
    end
  end

  describe "ordered/1" do
    test "orders pages with pinned first, then by updated_at descending" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, page1} = Pages.create_page(user, workspace.id, %{title: "Page 1"})
      {:ok, page2} = Pages.create_page(user, workspace.id, %{title: "Page 2"})
      {:ok, page3} = Pages.create_page(user, workspace.id, %{title: "Page 3"})

      # Pin page1
      {:ok, _page1} = Pages.update_page(user, page1.id, %{is_pinned: true})

      results =
        Queries.base()
        |> Queries.for_user(user)
        |> Queries.ordered()
        |> Repo.all()

      page_ids = Enum.map(results, & &1.id)
      # Pinned first
      assert hd(page_ids) == page1.id
      # Remaining two are not pinned
      assert page2.id in page_ids
      assert page3.id in page_ids
    end

    test "orders multiple pinned pages by updated_at descending" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, page1} = Pages.create_page(user, workspace.id, %{title: "Page 1"})
      {:ok, page2} = Pages.create_page(user, workspace.id, %{title: "Page 2"})

      # Pin both
      {:ok, _page1} = Pages.update_page(user, page1.id, %{is_pinned: true})
      {:ok, _page2} = Pages.update_page(user, page2.id, %{is_pinned: true})

      results =
        Queries.base()
        |> Queries.for_user(user)
        |> Queries.ordered()
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
    test "preloads page components" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      {:ok, page} = Pages.create_page(user, workspace.id, %{title: "Page"})

      result =
        Queries.base()
        |> Queries.by_id(page.id)
        |> Queries.with_components()
        |> Repo.one()

      # Components should be loaded (list instead of NotLoaded)
      refute match?(%Ecto.Association.NotLoaded{}, result.page_components)
      assert is_list(result.page_components)
    end
  end

  describe "composable queries" do
    test "can combine multiple filters" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)
      {:ok, _} = Jarga.Workspaces.invite_member(user1, workspace.id, user2.email, :member)
      project = project_fixture(user1, workspace)

      # Create pages in different combinations
      {:ok, page1} =
        Pages.create_page(user1, workspace.id, %{title: "Page 1", project_id: project.id})

      {:ok, _page2} = Pages.create_page(user1, workspace.id, %{title: "Page 2"})

      {:ok, _page3} =
        Pages.create_page(user2, workspace.id, %{title: "Page 3", project_id: project.id})

      results =
        Queries.base()
        |> Queries.for_user(user1)
        |> Queries.for_workspace(workspace.id)
        |> Queries.for_project(project.id)
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).id == page1.id
    end
  end
end
