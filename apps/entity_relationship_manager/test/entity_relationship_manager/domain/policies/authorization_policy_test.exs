defmodule EntityRelationshipManager.Domain.Policies.AuthorizationPolicyTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Domain.Policies.AuthorizationPolicy

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

  describe "can?/2 - owner role" do
    test "owner can perform all actions" do
      for action <- @all_actions do
        assert AuthorizationPolicy.can?(:owner, action),
               "Expected owner to be able to #{action}"
      end
    end
  end

  describe "can?/2 - admin role" do
    test "admin can perform all actions" do
      for action <- @all_actions do
        assert AuthorizationPolicy.can?(:admin, action),
               "Expected admin to be able to #{action}"
      end
    end
  end

  describe "can?/2 - member role" do
    test "member can read and write entities/edges but not write schema" do
      allowed = [
        :read_schema,
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

      for action <- allowed do
        assert AuthorizationPolicy.can?(:member, action),
               "Expected member to be able to #{action}"
      end
    end

    test "member cannot write schema" do
      refute AuthorizationPolicy.can?(:member, :write_schema)
    end
  end

  describe "can?/2 - guest role" do
    test "guest can only read" do
      allowed = [:read_schema, :read_entity, :read_edge, :traverse]

      for action <- allowed do
        assert AuthorizationPolicy.can?(:guest, action),
               "Expected guest to be able to #{action}"
      end
    end

    test "guest cannot write" do
      denied = [
        :write_schema,
        :create_entity,
        :update_entity,
        :delete_entity,
        :create_edge,
        :update_edge,
        :delete_edge,
        :bulk_create,
        :bulk_update,
        :bulk_delete
      ]

      for action <- denied do
        refute AuthorizationPolicy.can?(:guest, action),
               "Expected guest NOT to be able to #{action}"
      end
    end
  end

  describe "can?/2 - unknown role" do
    test "unknown role cannot perform any actions" do
      for action <- @all_actions do
        refute AuthorizationPolicy.can?(:unknown, action),
               "Expected unknown role NOT to be able to #{action}"
      end
    end
  end
end
