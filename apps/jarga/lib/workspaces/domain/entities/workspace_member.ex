defmodule Jarga.Workspaces.Domain.Entities.WorkspaceMember do
  @moduledoc """
  Pure domain entity for workspace membership.

  This is a value object representing a user's membership in a workspace.
  It contains no infrastructure dependencies (no Ecto, no database concerns).

  For database persistence, see Jarga.Workspaces.Infrastructure.Schemas.WorkspaceMemberSchema.
  """

  @type role :: :owner | :admin | :member | :guest

  @type t :: %__MODULE__{
          id: String.t() | nil,
          email: String.t(),
          role: role(),
          invited_at: DateTime.t() | nil,
          joined_at: DateTime.t() | nil,
          workspace_id: String.t(),
          user_id: String.t() | nil,
          invited_by: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  defstruct [
    :id,
    :email,
    :role,
    :invited_at,
    :joined_at,
    :workspace_id,
    :user_id,
    :invited_by,
    :inserted_at,
    :updated_at
  ]

  @doc """
  Creates a new WorkspaceMember domain entity from attributes.
  """
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Converts an infrastructure schema to a domain entity.
  """
  def from_schema(%{__struct__: _} = schema) do
    %__MODULE__{
      id: schema.id,
      email: schema.email,
      role: schema.role,
      invited_at: schema.invited_at,
      joined_at: schema.joined_at,
      workspace_id: schema.workspace_id,
      user_id: schema.user_id,
      invited_by: schema.invited_by,
      inserted_at: schema.inserted_at,
      updated_at: schema.updated_at
    }
  end

  @doc """
  Checks if member has accepted invitation (business rule).
  """
  def accepted?(%__MODULE__{joined_at: joined_at}), do: !is_nil(joined_at)

  @doc """
  Checks if member is pending invitation (business rule).
  """
  def pending?(%__MODULE__{joined_at: joined_at}), do: is_nil(joined_at)

  @doc """
  Checks if member has owner role (business rule).
  """
  def owner?(%__MODULE__{role: :owner}), do: true
  def owner?(_), do: false

  @doc """
  Checks if member has admin or owner role (business rule).
  """
  def admin_or_owner?(%__MODULE__{role: role}) when role in [:owner, :admin], do: true
  def admin_or_owner?(_), do: false
end
