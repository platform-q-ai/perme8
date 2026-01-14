# credo:disable-for-this-file Jarga.Credo.Check.Architecture.NoDirectRepoInUseCases
defmodule Jarga.Documents.Application.UseCases.DeleteDocumentTest do
  use Jarga.DataCase, async: true

  alias Jarga.Documents.Application.UseCases.DeleteDocument
  alias Jarga.Documents.Infrastructure.Schemas.DocumentSchema

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures
  import Jarga.DocumentsFixtures

  describe "execute/2 - successful document deletion" do
    test "owner can delete their own document" do
      owner = user_fixture()
      workspace = workspace_fixture(owner)
      document = document_fixture(owner, workspace, nil, %{})

      params = %{
        actor: owner,
        document_id: document.id
      }

      assert {:ok, deleted_document} = DeleteDocument.execute(params)
      assert deleted_document.id == document.id

      # Verify document is deleted from database
      refute Repo.get(DocumentSchema, document.id)
    end

    test "admin can delete public documents they don't own" do
      owner = user_fixture()
      admin = user_fixture()
      workspace = workspace_fixture(owner)
      {:ok, _} = invite_and_accept_member(owner, workspace.id, admin.email, :admin)

      document = document_fixture(owner, workspace, nil, %{is_public: true})

      params = %{
        actor: admin,
        document_id: document.id
      }

      assert {:ok, deleted_document} = DeleteDocument.execute(params)
      assert deleted_document.id == document.id
    end

    test "admin can delete their own private document" do
      owner = user_fixture()
      admin = user_fixture()
      workspace = workspace_fixture(owner)
      {:ok, _} = invite_and_accept_member(owner, workspace.id, admin.email, :admin)

      document = document_fixture(admin, workspace, nil, %{is_public: false})

      params = %{
        actor: admin,
        document_id: document.id
      }

      assert {:ok, deleted_document} = DeleteDocument.execute(params)
      assert deleted_document.id == document.id
    end

    test "member can delete their own document" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      document = document_fixture(member, workspace, nil, %{})

      params = %{
        actor: member,
        document_id: document.id
      }

      assert {:ok, deleted_document} = DeleteDocument.execute(params)
      assert deleted_document.id == document.id
    end
  end

  describe "execute/2 - authorization failures" do
    test "member cannot delete documents they don't own" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      document = document_fixture(owner, workspace, nil, %{is_public: true})

      params = %{
        actor: member,
        document_id: document.id
      }

      assert {:error, :forbidden} = DeleteDocument.execute(params)

      # Verify document still exists
      assert Repo.get(DocumentSchema, document.id)
    end

    test "admin cannot delete private documents they don't own" do
      owner = user_fixture()
      admin = user_fixture()
      workspace = workspace_fixture(owner)
      {:ok, _} = invite_and_accept_member(owner, workspace.id, admin.email, :admin)

      document = document_fixture(owner, workspace, nil, %{is_public: false})

      params = %{
        actor: admin,
        document_id: document.id
      }

      assert {:error, :forbidden} = DeleteDocument.execute(params)
      assert Repo.get(DocumentSchema, document.id)
    end

    test "guest cannot delete any documents" do
      owner = user_fixture()
      guest = user_fixture()
      workspace = workspace_fixture(owner)
      {:ok, _} = invite_and_accept_member(owner, workspace.id, guest.email, :guest)

      document = document_fixture(owner, workspace, nil, %{is_public: true})

      params = %{
        actor: guest,
        document_id: document.id
      }

      assert {:error, :forbidden} = DeleteDocument.execute(params)
      assert Repo.get(DocumentSchema, document.id)
    end

    test "non-member cannot delete documents" do
      owner = user_fixture()
      non_member = user_fixture()
      workspace = workspace_fixture(owner)
      document = document_fixture(owner, workspace, nil, %{})

      params = %{
        actor: non_member,
        document_id: document.id
      }

      assert {:error, reason} = DeleteDocument.execute(params)
      assert reason in [:workspace_not_found, :unauthorized]
      assert Repo.get(DocumentSchema, document.id)
    end

    test "returns error when document doesn't exist" do
      owner = user_fixture()
      _workspace = workspace_fixture(owner)
      fake_document_id = Ecto.UUID.generate()

      params = %{
        actor: owner,
        document_id: fake_document_id
      }

      assert {:error, :document_not_found} = DeleteDocument.execute(params)
    end

    test "returns error when user cannot access private document" do
      owner = user_fixture()
      member = user_fixture()
      workspace = workspace_fixture(owner)
      {:ok, _} = invite_and_accept_member(owner, workspace.id, member.email, :member)

      # Private document owned by someone else
      document = document_fixture(owner, workspace, nil, %{is_public: false})

      params = %{
        actor: member,
        document_id: document.id
      }

      assert {:error, :forbidden} = DeleteDocument.execute(params)
    end
  end
end
