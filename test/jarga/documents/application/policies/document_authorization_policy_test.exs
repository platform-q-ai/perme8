defmodule Jarga.Documents.Application.Policies.DocumentAuthorizationPolicyTest do
  use ExUnit.Case, async: true

  alias Jarga.Documents.Application.Policies.DocumentAuthorizationPolicy
  alias Jarga.Documents.Domain.Entities.Document

  describe "can_edit?/3" do
    test "owner can edit their own document" do
      user_id = Ecto.UUID.generate()
      document = %Document{user_id: user_id, is_public: false}

      assert DocumentAuthorizationPolicy.can_edit?(document, :member, user_id)
    end

    test "member can edit public documents they don't own" do
      owner_id = Ecto.UUID.generate()
      member_id = Ecto.UUID.generate()
      document = %Document{user_id: owner_id, is_public: true}

      assert DocumentAuthorizationPolicy.can_edit?(document, :member, member_id)
    end

    test "member cannot edit private documents they don't own" do
      owner_id = Ecto.UUID.generate()
      member_id = Ecto.UUID.generate()
      document = %Document{user_id: owner_id, is_public: false}

      refute DocumentAuthorizationPolicy.can_edit?(document, :member, member_id)
    end

    test "admin can edit public documents" do
      owner_id = Ecto.UUID.generate()
      admin_id = Ecto.UUID.generate()
      document = %Document{user_id: owner_id, is_public: true}

      assert DocumentAuthorizationPolicy.can_edit?(document, :admin, admin_id)
    end

    test "admin cannot edit private documents they don't own" do
      owner_id = Ecto.UUID.generate()
      admin_id = Ecto.UUID.generate()
      document = %Document{user_id: owner_id, is_public: false}

      refute DocumentAuthorizationPolicy.can_edit?(document, :admin, admin_id)
    end

    test "guest cannot edit any documents" do
      owner_id = Ecto.UUID.generate()
      guest_id = Ecto.UUID.generate()
      document = %Document{user_id: owner_id, is_public: true}

      refute DocumentAuthorizationPolicy.can_edit?(document, :guest, guest_id)
    end
  end

  describe "can_delete?/3" do
    test "owner can delete their own document" do
      user_id = Ecto.UUID.generate()
      document = %Document{user_id: user_id, is_public: false}

      assert DocumentAuthorizationPolicy.can_delete?(document, :member, user_id)
    end

    test "member cannot delete documents they don't own" do
      owner_id = Ecto.UUID.generate()
      member_id = Ecto.UUID.generate()
      document = %Document{user_id: owner_id, is_public: true}

      refute DocumentAuthorizationPolicy.can_delete?(document, :member, member_id)
    end

    test "admin can delete public documents" do
      owner_id = Ecto.UUID.generate()
      admin_id = Ecto.UUID.generate()
      document = %Document{user_id: owner_id, is_public: true}

      assert DocumentAuthorizationPolicy.can_delete?(document, :admin, admin_id)
    end

    test "admin cannot delete private documents they don't own" do
      owner_id = Ecto.UUID.generate()
      admin_id = Ecto.UUID.generate()
      document = %Document{user_id: owner_id, is_public: false}

      refute DocumentAuthorizationPolicy.can_delete?(document, :admin, admin_id)
    end

    test "owner admin can delete their own private document" do
      user_id = Ecto.UUID.generate()
      document = %Document{user_id: user_id, is_public: false}

      assert DocumentAuthorizationPolicy.can_delete?(document, :admin, user_id)
    end

    test "guest cannot delete any documents" do
      guest_id = Ecto.UUID.generate()
      document = %Document{user_id: guest_id, is_public: false}

      refute DocumentAuthorizationPolicy.can_delete?(document, :guest, guest_id)
    end
  end

  describe "can_pin?/3" do
    test "member can pin their own document" do
      user_id = Ecto.UUID.generate()
      document = %Document{user_id: user_id, is_public: false}

      assert DocumentAuthorizationPolicy.can_pin?(document, :member, user_id)
    end

    test "member can pin public documents" do
      owner_id = Ecto.UUID.generate()
      member_id = Ecto.UUID.generate()
      document = %Document{user_id: owner_id, is_public: true}

      assert DocumentAuthorizationPolicy.can_pin?(document, :member, member_id)
    end

    test "member cannot pin private documents they don't own" do
      owner_id = Ecto.UUID.generate()
      member_id = Ecto.UUID.generate()
      document = %Document{user_id: owner_id, is_public: false}

      refute DocumentAuthorizationPolicy.can_pin?(document, :member, member_id)
    end

    test "admin can pin public documents" do
      owner_id = Ecto.UUID.generate()
      admin_id = Ecto.UUID.generate()
      document = %Document{user_id: owner_id, is_public: true}

      assert DocumentAuthorizationPolicy.can_pin?(document, :admin, admin_id)
    end

    test "admin cannot pin private documents they don't own" do
      owner_id = Ecto.UUID.generate()
      admin_id = Ecto.UUID.generate()
      document = %Document{user_id: owner_id, is_public: false}

      refute DocumentAuthorizationPolicy.can_pin?(document, :admin, admin_id)
    end

    test "guest cannot pin any documents" do
      owner_id = Ecto.UUID.generate()
      guest_id = Ecto.UUID.generate()
      document = %Document{user_id: owner_id, is_public: true}

      refute DocumentAuthorizationPolicy.can_pin?(document, :guest, guest_id)
    end
  end
end
