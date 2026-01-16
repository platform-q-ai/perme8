defmodule Jarga.Documents.Domain.Policies.DocumentAccessPolicyTest do
  use ExUnit.Case, async: true

  alias Jarga.Documents.Domain.Policies.DocumentAccessPolicy
  alias Jarga.Documents.Domain.Entities.Document

  describe "can_access?/2" do
    test "returns true when user owns the document" do
      user_id = Ecto.UUID.generate()
      document = %Document{user_id: user_id, is_public: false}

      assert DocumentAccessPolicy.can_access?(document, user_id)
    end

    test "returns true when document is public and user is not the owner" do
      owner_id = Ecto.UUID.generate()
      other_user_id = Ecto.UUID.generate()
      document = %Document{user_id: owner_id, is_public: true}

      assert DocumentAccessPolicy.can_access?(document, other_user_id)
    end

    test "returns false when document is private and user is not the owner" do
      owner_id = Ecto.UUID.generate()
      other_user_id = Ecto.UUID.generate()
      document = %Document{user_id: owner_id, is_public: false}

      refute DocumentAccessPolicy.can_access?(document, other_user_id)
    end

    test "returns true when document is public and user is the owner" do
      user_id = Ecto.UUID.generate()
      document = %Document{user_id: user_id, is_public: true}

      assert DocumentAccessPolicy.can_access?(document, user_id)
    end
  end
end
