defmodule Identity.Infrastructure.Schemas.WorkspaceMemberSchemaTest do
  use Identity.DataCase, async: true

  alias Identity.Infrastructure.Schemas.WorkspaceMemberSchema
  alias Identity.Infrastructure.Schemas.WorkspaceSchema
  alias Identity.Domain.Entities.WorkspaceMember

  import Identity.AccountsFixtures

  defp create_workspace(_context \\ %{}) do
    {:ok, workspace} =
      %WorkspaceSchema{}
      |> WorkspaceSchema.changeset(%{
        name: "Test Workspace",
        slug: "test-ws-#{System.unique_integer([:positive])}"
      })
      |> Repo.insert()

    %{workspace: workspace}
  end

  describe "changeset/2" do
    test "validates required fields" do
      changeset = WorkspaceMemberSchema.changeset(%WorkspaceMemberSchema{}, %{})
      refute changeset.valid?
      errors = errors_on(changeset)

      assert %{
               workspace_id: ["can't be blank"],
               email: ["can't be blank"],
               role: ["can't be blank"]
             } = errors
    end

    test "valid changeset with required fields" do
      %{workspace: workspace} = create_workspace()

      changeset =
        WorkspaceMemberSchema.changeset(%WorkspaceMemberSchema{}, %{
          workspace_id: workspace.id,
          email: "test@example.com",
          role: :member
        })

      assert changeset.valid?
    end

    test "enforces foreign key constraints" do
      fake_workspace_id = Ecto.UUID.generate()

      {:error, changeset} =
        %WorkspaceMemberSchema{}
        |> WorkspaceMemberSchema.changeset(%{
          workspace_id: fake_workspace_id,
          email: "test@example.com",
          role: :member
        })
        |> Repo.insert()

      assert %{workspace_id: ["does not exist"]} = errors_on(changeset)
    end

    test "enforces unique constraint on workspace_id and email" do
      %{workspace: workspace} = create_workspace()

      {:ok, _} =
        %WorkspaceMemberSchema{}
        |> WorkspaceMemberSchema.changeset(%{
          workspace_id: workspace.id,
          email: "duplicate@example.com",
          role: :member
        })
        |> Repo.insert()

      {:error, changeset} =
        %WorkspaceMemberSchema{}
        |> WorkspaceMemberSchema.changeset(%{
          workspace_id: workspace.id,
          email: "duplicate@example.com",
          role: :admin
        })
        |> Repo.insert()

      assert %{workspace_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "accepts domain entity and converts to schema" do
      member = %WorkspaceMember{
        id: Ecto.UUID.generate(),
        workspace_id: Ecto.UUID.generate(),
        email: "test@example.com",
        role: :member
      }

      changeset = WorkspaceMemberSchema.changeset(member, %{role: :admin})
      assert changeset.valid?
    end
  end

  describe "accept_invitation_changeset/2" do
    test "validates required user_id and joined_at" do
      changeset =
        WorkspaceMemberSchema.accept_invitation_changeset(%WorkspaceMemberSchema{}, %{})

      refute changeset.valid?
      errors = errors_on(changeset)
      assert %{user_id: ["can't be blank"], joined_at: ["can't be blank"]} = errors
    end

    test "valid accept invitation changeset" do
      user = user_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      changeset =
        WorkspaceMemberSchema.accept_invitation_changeset(%WorkspaceMemberSchema{}, %{
          user_id: user.id,
          joined_at: now
        })

      assert changeset.valid?
    end

    test "accepts domain entity and converts to schema" do
      user = user_fixture()
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      member = %WorkspaceMember{
        id: Ecto.UUID.generate(),
        workspace_id: Ecto.UUID.generate(),
        email: "test@example.com",
        role: :member
      }

      changeset =
        WorkspaceMemberSchema.accept_invitation_changeset(member, %{
          user_id: user.id,
          joined_at: now
        })

      assert changeset.valid?
    end
  end

  describe "to_schema/1" do
    test "converts domain entity to schema struct" do
      member = %WorkspaceMember{
        id: "test-id",
        email: "test@example.com",
        role: :admin,
        invited_at: ~U[2025-01-01 00:00:00Z],
        joined_at: ~U[2025-01-02 00:00:00Z],
        workspace_id: "workspace-id",
        user_id: "user-id",
        invited_by: "inviter-id",
        inserted_at: ~U[2025-01-01 00:00:00Z],
        updated_at: ~U[2025-01-01 00:00:00Z]
      }

      schema = WorkspaceMemberSchema.to_schema(member)

      assert %WorkspaceMemberSchema{} = schema
      assert schema.id == "test-id"
      assert schema.email == "test@example.com"
      assert schema.role == :admin
      assert schema.workspace_id == "workspace-id"
      assert schema.user_id == "user-id"
      assert schema.invited_by == "inviter-id"
    end

    test "returns schema unchanged if already a schema" do
      schema = %WorkspaceMemberSchema{
        id: "test-id",
        email: "test@example.com",
        role: :member
      }

      assert ^schema = WorkspaceMemberSchema.to_schema(schema)
    end
  end
end
