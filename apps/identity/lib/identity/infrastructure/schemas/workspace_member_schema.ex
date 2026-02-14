defmodule Identity.Infrastructure.Schemas.WorkspaceMemberSchema do
  @moduledoc """
  Ecto schema for workspace membership.

  This is the infrastructure representation that handles database persistence.
  For the pure domain entity, see Identity.Domain.Entities.WorkspaceMember.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias Identity.Domain.Entities.WorkspaceMember

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workspace_members" do
    field(:email, :string)
    field(:role, Ecto.Enum, values: [:owner, :admin, :member, :guest])
    field(:invited_at, :utc_datetime)
    field(:joined_at, :utc_datetime)

    belongs_to(:workspace, Identity.Infrastructure.Schemas.WorkspaceSchema)
    belongs_to(:user, Identity.Infrastructure.Schemas.UserSchema)

    belongs_to(:inviter, Identity.Infrastructure.Schemas.UserSchema, foreign_key: :invited_by)

    timestamps(type: :utc_datetime)
  end

  @doc """
  Converts a domain entity to a schema struct.
  If already a schema, returns it unchanged.
  """
  def to_schema(%__MODULE__{} = schema), do: schema

  def to_schema(%WorkspaceMember{} = member) do
    %__MODULE__{
      id: member.id,
      email: member.email,
      role: member.role,
      invited_at: member.invited_at,
      joined_at: member.joined_at,
      workspace_id: member.workspace_id,
      user_id: member.user_id,
      invited_by: member.invited_by,
      inserted_at: member.inserted_at,
      updated_at: member.updated_at
    }
  end

  @doc """
  Changeset for creating/updating workspace members.
  Accepts either a schema struct or a domain entity.
  """
  def changeset(workspace_member_or_schema, attrs)

  def changeset(%WorkspaceMember{} = member, attrs) do
    member
    |> to_schema()
    |> changeset(attrs)
  end

  def changeset(%__MODULE__{} = schema, attrs) do
    schema
    |> cast(attrs, [:workspace_id, :user_id, :email, :role, :invited_by, :invited_at, :joined_at])
    |> validate_required([:workspace_id, :email, :role])
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:invited_by)
    |> unique_constraint([:workspace_id, :email])
  end

  @doc """
  Changeset for accepting a workspace invitation.
  Updates the user_id and joined_at fields to mark the invitation as accepted.
  """
  def accept_invitation_changeset(workspace_member_or_schema, attrs)

  def accept_invitation_changeset(%WorkspaceMember{} = member, attrs) do
    member
    |> to_schema()
    |> accept_invitation_changeset(attrs)
  end

  def accept_invitation_changeset(%__MODULE__{} = schema, attrs) do
    schema
    |> cast(attrs, [:user_id, :joined_at])
    |> validate_required([:user_id, :joined_at])
    |> foreign_key_constraint(:user_id)
  end
end
