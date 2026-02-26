defmodule Identity.Infrastructure.Migrations.IdentitySchemaTest do
  @moduledoc """
  Verifies that the identity-owned database schema exists and has the expected
  structure. These tests validate database state (table/column existence) using
  raw SQL queries against Identity.Repo.
  """
  use Identity.DataCase, async: false

  describe "workspace_role enum" do
    test "exists in the database" do
      result = Identity.Repo.query!("SELECT 1 FROM pg_type WHERE typname = 'workspace_role'")
      assert length(result.rows) == 1
    end

    test "has expected values" do
      result =
        Identity.Repo.query!("""
        SELECT enumlabel FROM pg_enum
        JOIN pg_type ON pg_enum.enumtypid = pg_type.oid
        WHERE pg_type.typname = 'workspace_role'
        ORDER BY enumsortorder
        """)

      values = Enum.map(result.rows, &hd/1)
      assert values == ["owner", "admin", "member", "guest"]
    end
  end

  describe "users table" do
    test "exists with expected columns" do
      result =
        Identity.Repo.query!("""
        SELECT column_name FROM information_schema.columns
        WHERE table_name = 'users'
        ORDER BY ordinal_position
        """)

      columns = Enum.map(result.rows, &hd/1)
      assert "id" in columns
      assert "first_name" in columns
      assert "last_name" in columns
      assert "email" in columns
      assert "role" in columns
      assert "date_created" in columns
      assert "last_login" in columns
      assert "status" in columns
      assert "avatar_url" in columns
    end

    test "has unique index on email" do
      result =
        Identity.Repo.query!("""
        SELECT indexname FROM pg_indexes
        WHERE tablename = 'users' AND indexdef LIKE '%UNIQUE%' AND indexdef LIKE '%email%'
        """)

      assert length(result.rows) >= 1
    end
  end

  describe "workspaces table" do
    test "exists with expected columns" do
      result =
        Identity.Repo.query!("""
        SELECT column_name FROM information_schema.columns
        WHERE table_name = 'workspaces'
        ORDER BY ordinal_position
        """)

      columns = Enum.map(result.rows, &hd/1)
      assert "id" in columns
      assert "name" in columns
      assert "description" in columns
      assert "color" in columns
      assert "is_archived" in columns
      assert "inserted_at" in columns
      assert "updated_at" in columns
    end
  end

  describe "workspace_members table" do
    test "exists with expected columns" do
      result =
        Identity.Repo.query!("""
        SELECT column_name FROM information_schema.columns
        WHERE table_name = 'workspace_members'
        ORDER BY ordinal_position
        """)

      columns = Enum.map(result.rows, &hd/1)
      assert "id" in columns
      assert "workspace_id" in columns
      assert "user_id" in columns
      assert "email" in columns
      assert "role" in columns
      assert "invited_by" in columns
      assert "invited_at" in columns
      assert "joined_at" in columns
      assert "inserted_at" in columns
      assert "updated_at" in columns
    end

    test "has unique index on workspace_id and email" do
      result =
        Identity.Repo.query!("""
        SELECT indexname FROM pg_indexes
        WHERE tablename = 'workspace_members'
        AND indexdef LIKE '%UNIQUE%'
        AND indexdef LIKE '%workspace_id%'
        AND indexdef LIKE '%email%'
        """)

      assert length(result.rows) >= 1
    end
  end

  describe "workspace_invitations table" do
    test "exists with expected columns" do
      result =
        Identity.Repo.query!("""
        SELECT column_name FROM information_schema.columns
        WHERE table_name = 'workspace_invitations'
        ORDER BY ordinal_position
        """)

      columns = Enum.map(result.rows, &hd/1)
      assert "id" in columns
      assert "workspace_id" in columns
      assert "email" in columns
      assert "role" in columns
      assert "invited_by" in columns
      assert "invited_at" in columns
      assert "expires_at" in columns
      assert "status" in columns
    end
  end

  describe "users_tokens table" do
    test "exists with expected columns" do
      result =
        Identity.Repo.query!("""
        SELECT column_name FROM information_schema.columns
        WHERE table_name = 'users_tokens'
        ORDER BY ordinal_position
        """)

      columns = Enum.map(result.rows, &hd/1)
      assert "id" in columns
      assert "user_id" in columns
      assert "token" in columns
      assert "context" in columns
      assert "sent_to" in columns
    end

    test "has unique index on context and token" do
      result =
        Identity.Repo.query!("""
        SELECT indexname FROM pg_indexes
        WHERE tablename = 'users_tokens'
        AND indexdef LIKE '%UNIQUE%'
        AND indexdef LIKE '%context%'
        AND indexdef LIKE '%token%'
        """)

      assert length(result.rows) >= 1
    end
  end

  describe "users auth columns" do
    test "hashed_password column exists" do
      result =
        Identity.Repo.query!("""
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'hashed_password'
        """)

      assert length(result.rows) == 1
    end

    test "confirmed_at column exists" do
      result =
        Identity.Repo.query!("""
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'confirmed_at'
        """)

      assert length(result.rows) == 1
    end

    test "citext extension is installed" do
      result =
        Identity.Repo.query!("""
        SELECT 1 FROM pg_extension WHERE extname = 'citext'
        """)

      assert length(result.rows) == 1
    end
  end

  describe "workspaces slug" do
    test "slug column exists" do
      result =
        Identity.Repo.query!("""
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'workspaces' AND column_name = 'slug'
        """)

      assert length(result.rows) == 1
    end

    test "slug has unique index" do
      result =
        Identity.Repo.query!("""
        SELECT indexname FROM pg_indexes
        WHERE tablename = 'workspaces'
        AND indexdef LIKE '%UNIQUE%'
        AND indexdef LIKE '%slug%'
        """)

      assert length(result.rows) >= 1
    end
  end

  describe "workspace_members composite index" do
    test "composite index on workspace_id and user_id exists" do
      result =
        Identity.Repo.query!("""
        SELECT indexname FROM pg_indexes
        WHERE tablename = 'workspace_members'
        AND indexdef LIKE '%workspace_id%'
        AND indexdef LIKE '%user_id%'
        """)

      assert length(result.rows) >= 1
    end
  end

  describe "user preferences" do
    test "preferences column exists and is jsonb" do
      result =
        Identity.Repo.query!("""
        SELECT data_type FROM information_schema.columns
        WHERE table_name = 'users' AND column_name = 'preferences'
        """)

      assert result.rows == [["jsonb"]]
    end

    test "preferences has GIN index" do
      result =
        Identity.Repo.query!("""
        SELECT indexname FROM pg_indexes
        WHERE tablename = 'users'
        AND indexdef LIKE '%gin%'
        AND indexdef LIKE '%preferences%'
        """)

      assert length(result.rows) >= 1
    end
  end

  describe "api_keys table" do
    test "exists with expected columns" do
      result =
        Identity.Repo.query!("""
        SELECT column_name FROM information_schema.columns
        WHERE table_name = 'api_keys'
        ORDER BY ordinal_position
        """)

      columns = Enum.map(result.rows, &hd/1)
      assert "id" in columns
      assert "name" in columns
      assert "description" in columns
      assert "hashed_token" in columns
      assert "user_id" in columns
      assert "workspace_access" in columns
      assert "is_active" in columns
      assert "inserted_at" in columns
      assert "updated_at" in columns
    end

    test "has index on user_id" do
      result =
        Identity.Repo.query!("""
        SELECT indexname FROM pg_indexes
        WHERE tablename = 'api_keys'
        AND indexdef LIKE '%user_id%'
        """)

      assert length(result.rows) >= 1
    end

    test "has unique index on hashed_token" do
      result =
        Identity.Repo.query!("""
        SELECT indexname FROM pg_indexes
        WHERE tablename = 'api_keys'
        AND indexdef LIKE '%UNIQUE%'
        AND indexdef LIKE '%hashed_token%'
        """)

      assert length(result.rows) >= 1
    end
  end
end
