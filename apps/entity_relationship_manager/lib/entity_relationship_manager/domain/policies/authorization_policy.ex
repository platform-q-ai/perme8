defmodule EntityRelationshipManager.Domain.Policies.AuthorizationPolicy do
  @moduledoc """
  Domain policy for role-based authorization in the Entity Relationship Manager.

  Pure functions that determine whether a role can perform a given action.

  ## Roles

  - `:owner` - Full access to all operations
  - `:admin` - Full access to all operations
  - `:member` - All operations except schema writes
  - `:guest` - Read-only access (read_schema, read_entity, read_edge, traverse)

  ## Actions

  Schema: `:read_schema`, `:write_schema`
  Entity: `:create_entity`, `:read_entity`, `:update_entity`, `:delete_entity`
  Edge: `:create_edge`, `:read_edge`, `:update_edge`, `:delete_edge`
  Graph: `:traverse`
  Bulk: `:bulk_create`, `:bulk_update`, `:bulk_delete`

  NO I/O, NO database, NO side effects.
  """

  @type role :: :owner | :admin | :member | :guest
  @type action ::
          :read_schema
          | :write_schema
          | :create_entity
          | :read_entity
          | :update_entity
          | :delete_entity
          | :create_edge
          | :read_edge
          | :update_edge
          | :delete_edge
          | :traverse
          | :bulk_create
          | :bulk_update
          | :bulk_delete

  @all_actions [
    :read_schema,
    :write_schema,
    :create_entity,
    :read_entity,
    :update_entity,
    :delete_entity,
    :create_edge,
    :read_edge,
    :update_edge,
    :delete_edge,
    :traverse,
    :bulk_create,
    :bulk_update,
    :bulk_delete
  ]

  @member_actions @all_actions -- [:write_schema]

  @guest_actions [:read_schema, :read_entity, :read_edge, :traverse]

  @doc """
  Returns true if the given role can perform the given action.

  ## Examples

      iex> AuthorizationPolicy.can?(:owner, :write_schema)
      true

      iex> AuthorizationPolicy.can?(:guest, :write_schema)
      false
  """
  @spec can?(role(), action()) :: boolean()
  def can?(:owner, action) when action in @all_actions, do: true
  def can?(:admin, action) when action in @all_actions, do: true
  def can?(:member, action) when action in @member_actions, do: true
  def can?(:guest, action) when action in @guest_actions, do: true
  def can?(_role, _action), do: false
end
