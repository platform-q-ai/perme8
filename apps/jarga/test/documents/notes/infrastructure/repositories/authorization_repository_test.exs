defmodule Jarga.Documents.Notes.Infrastructure.AuthorizationRepositoryTest do
  use Jarga.DataCase, async: true

  alias Jarga.Documents.Notes.Infrastructure.Repositories.AuthorizationRepository
  alias Jarga.Documents
  alias Jarga.Documents.Infrastructure.Schemas.DocumentComponentSchema
  # Use Identity.Repo for all operations to ensure consistent transaction visibility
  alias Identity.Repo, as: Repo

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
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      # Create note owned by owner
      note = note_fixture(owner, workspace.id)

      # Member cannot access owner's note
      assert {:error, :unauthorized} = AuthorizationRepository.verify_note_access(member, note.id)
    end
  end

  describe "verify_note_access_via_document/2" do
    test "returns {:ok, note} when user owns the document containing the note" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      note = note_fixture(user, workspace.id)

      # Create a document with the note as a component
      {:ok, document} = Documents.create_document(user, workspace.id, %{title: "My Document"})

      %DocumentComponentSchema{}
      |> DocumentComponentSchema.changeset(%{
        document_id: document.id,
        component_type: "note",
        component_id: note.id,
        position: 0
      })
      |> Repo.insert!()

      assert {:ok, fetched_note} =
               AuthorizationRepository.verify_note_access_via_document(user, note.id)

      assert fetched_note.id == note.id
    end

    test "returns {:ok, note} when note is in a public document in user's workspace" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)

      # Add member to workspace
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      # Create note owned by owner
      note = note_fixture(owner, workspace.id)

      # Create a public document with the note
      {:ok, document} =
        Documents.create_document(owner, workspace.id, %{title: "Public Document"})

      %DocumentComponentSchema{}
      |> DocumentComponentSchema.changeset(%{
        document_id: document.id,
        component_type: "note",
        component_id: note.id,
        position: 0
      })
      |> Repo.insert!()

      {:ok, _document} = Documents.update_document(owner, document.id, %{is_public: true})

      # Member can access the note through the public document
      assert {:ok, fetched_note} =
               AuthorizationRepository.verify_note_access_via_document(member, note.id)

      assert fetched_note.id == note.id
    end

    test "returns {:error, :unauthorized} when note is in a private document" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)

      # Add user2 to workspace
      {:ok, _} = invite_and_accept_member(user1, workspace.id, user2.email, :member)

      # Create note owned by user1
      note = note_fixture(user1, workspace.id)

      # Create a private document with the note
      {:ok, document} =
        Documents.create_document(user1, workspace.id, %{title: "Private Document"})

      %DocumentComponentSchema{}
      |> DocumentComponentSchema.changeset(%{
        document_id: document.id,
        component_type: "note",
        component_id: note.id,
        position: 0
      })
      |> Repo.insert!()

      # user2 cannot access the note through the private document
      assert {:error, :unauthorized} =
               AuthorizationRepository.verify_note_access_via_document(user2, note.id)
    end

    test "returns {:error, :note_not_found} when note doesn't exist" do
      user = user_fixture()
      fake_id = Ecto.UUID.generate()

      assert {:error, :note_not_found} =
               AuthorizationRepository.verify_note_access_via_document(user, fake_id)
    end

    test "returns {:error, :unauthorized} when user is not in any workspace with the note" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)
      note = note_fixture(user1, workspace.id)

      # Create a document with the note
      {:ok, document} = Documents.create_document(user1, workspace.id, %{title: "Document"})

      %DocumentComponentSchema{}
      |> DocumentComponentSchema.changeset(%{
        document_id: document.id,
        component_type: "note",
        component_id: note.id,
        position: 0
      })
      |> Repo.insert!()

      # user2 is not a workspace member
      assert {:error, :unauthorized} =
               AuthorizationRepository.verify_note_access_via_document(user2, note.id)
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
