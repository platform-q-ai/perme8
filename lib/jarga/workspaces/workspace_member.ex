defmodule Jarga.Workspaces.WorkspaceMember do
  @moduledoc """
  Schema for workspace membership with roles and invitation tracking.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "workspace_members" do
    field(:email, :string)
    field(:role, Ecto.Enum, values: [:owner, :admin, :member, :guest])
    field(:invited_at, :utc_datetime)
    field(:joined_at, :utc_datetime)

    belongs_to(:workspace, Jarga.Workspaces.Workspace)
    belongs_to(:user, Jarga.Accounts.User)
    belongs_to(:inviter, Jarga.Accounts.User, foreign_key: :invited_by)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(workspace_member, attrs) do
    workspace_member
    |> cast(attrs, [:workspace_id, :user_id, :email, :role, :invited_by, :invited_at, :joined_at])
    |> validate_required([:workspace_id, :email, :role])
    |> foreign_key_constraint(:workspace_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:invited_by)
    |> unique_constraint([:workspace_id, :email])
  end
end
