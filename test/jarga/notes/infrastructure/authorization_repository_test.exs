defmodule Jarga.Notes.Infrastructure.AuthorizationRepositoryTest do
  use Jarga.DataCase, async: true

  alias Jarga.Notes.Infrastructure.AuthorizationRepository
  alias Jarga.Pages
  alias Jarga.Pages.PageComponent
  alias Jarga.Repo

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.ProjectsFixtures
  import Jarga.NotesFixtures

  describe "verify_workspace_access/2" do
    test "returns {:ok, workspace} when user is a member" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert {:ok, fetched_workspace} =
               AuthorizationRepository.verify_workspace_access(user, workspace.id)

      assert fetched_workspace.id == workspace.id
    end

    test "returns {:error, :workspace_not_found} when workspace doesn't exist" do
      user = user_fixture()
      fake_id = Ecto.UUID.generate()

      assert {:error, :workspace_not_found} =
               AuthorizationRepository.verify_workspace_access(user, fake_id)
    end

    test "returns {:error, :unauthorized} when user is not a member" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)

      assert {:error, :unauthorized} =
               AuthorizationRepository.verify_workspace_access(user2, workspace.id)
    end
  end

  describe "verify_note_access/2" do
    test "returns {:ok, note} when user owns the note" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      note = note_fixture(user, workspace.id)

      assert {:ok, fetched_note} = AuthorizationRepository.verify_note_access(user, note.id)
      assert fetched_note.id == note.id
    end

    test "returns {:error, :note_not_found} when note doesn't exist" do
      user = user_fixture()
      fake_id = Ecto.UUID.generate()

      assert {:error, :note_not_found} = AuthorizationRepository.verify_note_access(user, fake_id)
    end

    test "returns {:error, :unauthorized} when note exists but belongs to another user" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)
      note = note_fixture(user1, workspace.id)

      assert {:error, :unauthorized} = AuthorizationRepository.verify_note_access(user2, note.id)
    end

    test "members cannot access other members' notes even in shared workspace" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)

      # Add member to workspace
      {:ok, _} = Jarga.Workspaces.invite_member(owner, workspace.id, member.email, :member)

      # Create note owned by owner
      note = note_fixture(owner, workspace.id)

      # Member cannot access owner's note
      assert {:error, :unauthorized} = AuthorizationRepository.verify_note_access(member, note.id)
    end
  end

  describe "verify_note_access_via_page/2" do
    test "returns {:ok, note} when user owns the page containing the note" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      note = note_fixture(user, workspace.id)

      # Create a page with the note as a component
      {:ok, page} = Pages.create_page(user, workspace.id, %{title: "My Page"})

      %PageComponent{}
      |> PageComponent.changeset(%{
        page_id: page.id,
        component_type: "note",
        component_id: note.id,
        position: 0
      })
      |> Repo.insert!()

      assert {:ok, fetched_note} =
               AuthorizationRepository.verify_note_access_via_page(user, note.id)

      assert fetched_note.id == note.id
    end

    test "returns {:ok, note} when note is in a public page in user's workspace" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)

      # Add member to workspace
      {:ok, _} = Jarga.Workspaces.invite_member(owner, workspace.id, member.email, :member)

      # Create note owned by owner
      note = note_fixture(owner, workspace.id)

      # Create a public page with the note
      {:ok, page} = Pages.create_page(owner, workspace.id, %{title: "Public Page"})

      %PageComponent{}
      |> PageComponent.changeset(%{
        page_id: page.id,
        component_type: "note",
        component_id: note.id,
        position: 0
      })
      |> Repo.insert!()

      {:ok, _page} = Pages.update_page(owner, page.id, %{is_public: true})

      # Member can access the note through the public page
      assert {:ok, fetched_note} =
               AuthorizationRepository.verify_note_access_via_page(member, note.id)

      assert fetched_note.id == note.id
    end

    test "returns {:error, :unauthorized} when note is in a private page" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)

      # Add user2 to workspace
      {:ok, _} = Jarga.Workspaces.invite_member(user1, workspace.id, user2.email, :member)

      # Create note owned by user1
      note = note_fixture(user1, workspace.id)

      # Create a private page with the note
      {:ok, page} = Pages.create_page(user1, workspace.id, %{title: "Private Page"})

      %PageComponent{}
      |> PageComponent.changeset(%{
        page_id: page.id,
        component_type: "note",
        component_id: note.id,
        position: 0
      })
      |> Repo.insert!()

      # user2 cannot access the note through the private page
      assert {:error, :unauthorized} =
               AuthorizationRepository.verify_note_access_via_page(user2, note.id)
    end

    test "returns {:error, :note_not_found} when note doesn't exist" do
      user = user_fixture()
      fake_id = Ecto.UUID.generate()

      assert {:error, :note_not_found} =
               AuthorizationRepository.verify_note_access_via_page(user, fake_id)
    end

    test "returns {:error, :unauthorized} when user is not in any workspace with the note" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)
      note = note_fixture(user1, workspace.id)

      # Create a page with the note
      {:ok, page} = Pages.create_page(user1, workspace.id, %{title: "Page"})

      %PageComponent{}
      |> PageComponent.changeset(%{
        page_id: page.id,
        component_type: "note",
        component_id: note.id,
        position: 0
      })
      |> Repo.insert!()

      # user2 is not a workspace member
      assert {:error, :unauthorized} =
               AuthorizationRepository.verify_note_access_via_page(user2, note.id)
    end
  end

  describe "verify_project_in_workspace/2" do
    test "returns :ok when project_id is nil" do
      workspace = workspace_fixture(user_fixture())

      assert :ok = AuthorizationRepository.verify_project_in_workspace(workspace.id, nil)
    end

    test "returns :ok when project belongs to workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      project = project_fixture(user, workspace)

      assert :ok =
               AuthorizationRepository.verify_project_in_workspace(workspace.id, project.id)
    end

    test "returns {:error, :invalid_project} when project doesn't exist" do
      workspace = workspace_fixture(user_fixture())
      fake_project_id = Ecto.UUID.generate()

      assert {:error, :invalid_project} =
               AuthorizationRepository.verify_project_in_workspace(workspace.id, fake_project_id)
    end

    test "returns {:error, :invalid_project} when project belongs to different workspace" do
      user = user_fixture()
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user)
      project = project_fixture(user, workspace2)

      assert {:error, :invalid_project} =
               AuthorizationRepository.verify_project_in_workspace(workspace1.id, project.id)
    end
  end
end
