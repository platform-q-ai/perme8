defmodule EntityRelationshipManager.Domain.Policies.InputSanitizationPolicyTest do
  use ExUnit.Case, async: true

  alias EntityRelationshipManager.Domain.Policies.InputSanitizationPolicy

  describe "validate_type_name/1" do
    test "accepts valid alphanumeric type names" do
      assert :ok = InputSanitizationPolicy.validate_type_name("User")
      assert :ok = InputSanitizationPolicy.validate_type_name("user_profile")
      assert :ok = InputSanitizationPolicy.validate_type_name("AUTHORED")
      assert :ok = InputSanitizationPolicy.validate_type_name("Type123")
      assert :ok = InputSanitizationPolicy.validate_type_name("a")
    end

    test "rejects empty string" do
      assert {:error, reason} = InputSanitizationPolicy.validate_type_name("")
      assert is_binary(reason)
    end

    test "rejects nil" do
      assert {:error, reason} = InputSanitizationPolicy.validate_type_name(nil)
      assert is_binary(reason)
    end

    test "rejects names with spaces" do
      assert {:error, _} = InputSanitizationPolicy.validate_type_name("has spaces")
    end

    test "rejects names with special characters" do
      assert {:error, _} = InputSanitizationPolicy.validate_type_name("has-dashes")
      assert {:error, _} = InputSanitizationPolicy.validate_type_name("has.dots")
      assert {:error, _} = InputSanitizationPolicy.validate_type_name("has@symbols")
      assert {:error, _} = InputSanitizationPolicy.validate_type_name("has!bang")
    end

    test "rejects names starting with a number" do
      assert {:error, _} = InputSanitizationPolicy.validate_type_name("123abc")
    end

    test "rejects names starting with underscore" do
      assert {:error, _} = InputSanitizationPolicy.validate_type_name("_private")
    end

    test "rejects names longer than 100 characters" do
      long_name = String.duplicate("a", 101)
      assert {:error, reason} = InputSanitizationPolicy.validate_type_name(long_name)
      assert is_binary(reason)
    end

    test "accepts names exactly 100 characters long" do
      name = String.duplicate("a", 100)
      assert :ok = InputSanitizationPolicy.validate_type_name(name)
    end
  end

  describe "validate_uuid/1" do
    test "accepts valid UUID v4" do
      assert :ok = InputSanitizationPolicy.validate_uuid("550e8400-e29b-41d4-a716-446655440000")
    end

    test "accepts valid UUID with lowercase" do
      assert :ok = InputSanitizationPolicy.validate_uuid("6ba7b810-9dad-11d1-80b4-00c04fd430c8")
    end

    test "accepts valid UUID with uppercase" do
      assert :ok = InputSanitizationPolicy.validate_uuid("6BA7B810-9DAD-11D1-80B4-00C04FD430C8")
    end

    test "rejects invalid UUID format" do
      assert {:error, reason} = InputSanitizationPolicy.validate_uuid("not-a-uuid")
      assert is_binary(reason)
    end

    test "rejects UUID with wrong number of characters" do
      assert {:error, _} = InputSanitizationPolicy.validate_uuid("550e8400-e29b-41d4-a716")
    end

    test "rejects nil" do
      assert {:error, _} = InputSanitizationPolicy.validate_uuid(nil)
    end

    test "rejects empty string" do
      assert {:error, _} = InputSanitizationPolicy.validate_uuid("")
    end

    test "rejects non-string" do
      assert {:error, _} = InputSanitizationPolicy.validate_uuid(12_345)
    end
  end
end
