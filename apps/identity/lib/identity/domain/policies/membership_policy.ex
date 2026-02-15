defmodule Identity.Domain.Policies.MembershipPolicy do
  @moduledoc """
  Pure domain policy for workspace membership business rules.

  This module contains pure business logic with no infrastructure dependencies.
  All functions are side-effect free and deterministic - they only evaluate
  business rules based on input data.

  Following Domain Layer principles:
  - No Repo, no Ecto, no database access
  - No external service calls
  - Pure functions only
  - Business rules that hold regardless of interface or infrastructure
  """

  @allowed_invitation_roles [:admin, :member, :guest]
  @allowed_role_changes [:admin, :member, :guest]
  @protected_roles [:owner]

  @doc """
  Validates if a role is allowed for invitations.

  Owner role is reserved for workspace creators and cannot be assigned via invitation.

  ## Examples

      iex> valid_invitation_role?(:admin)
      true

      iex> valid_invitation_role?(:owner)
      false

  """
  def valid_invitation_role?(role), do: role in @allowed_invitation_roles

  @doc """
  Validates if a role is allowed for role changes.

  Owner role cannot be assigned or changed - it's permanent for workspace creator.

  ## Examples

      iex> valid_role_change?(:member)
      true

      iex> valid_role_change?(:owner)
      false

  """
  def valid_role_change?(role), do: role in @allowed_role_changes

  @doc """
  Checks if a member's role can be changed.

  Business rule: Owner role is permanent and cannot be changed.

  ## Examples

      iex> can_change_role?(:owner)
      false

      iex> can_change_role?(:admin)
      true

  """
  def can_change_role?(member_role), do: member_role not in @protected_roles

  @doc """
  Checks if a member can be removed from a workspace.

  Business rule: Owner cannot be removed as they are the permanent workspace owner.

  ## Examples

      iex> can_remove_member?(:owner)
      false

      iex> can_remove_member?(:admin)
      true

  """
  def can_remove_member?(member_role), do: member_role not in @protected_roles

  @doc """
  Returns all roles that are allowed for invitations.

  ## Examples

      iex> allowed_invitation_roles()
      [:admin, :member, :guest]

  """
  def allowed_invitation_roles, do: @allowed_invitation_roles

  @doc """
  Returns all roles that are protected from modification.

  ## Examples

      iex> protected_roles()
      [:owner]

  """
  def protected_roles, do: @protected_roles
end
