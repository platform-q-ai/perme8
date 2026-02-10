defmodule Identity.Application.Services.PasswordServiceTest do
  @moduledoc """
  Unit tests for the PasswordService application service.

  These tests verify password hashing and verification behavior
  using Bcrypt.
  """

  use ExUnit.Case, async: true

  alias Identity.Application.Services.PasswordService

  describe "hash_password/1" do
    test "returns a Bcrypt hash starting with $2b$" do
      hash = PasswordService.hash_password("my_password")

      assert is_binary(hash)
      assert String.starts_with?(hash, "$2b$")
    end

    test "generates different hashes for the same password" do
      hash1 = PasswordService.hash_password("same_password")
      hash2 = PasswordService.hash_password("same_password")

      # Each hash should be unique due to random salt
      refute hash1 == hash2
    end

    test "generates a 60-character hash" do
      hash = PasswordService.hash_password("test123")

      assert String.length(hash) == 60
    end

    test "handles unicode passwords" do
      hash = PasswordService.hash_password("пароль密码🔐")

      assert is_binary(hash)
      assert String.starts_with?(hash, "$2b$")
    end

    test "handles long passwords" do
      long_password = String.duplicate("a", 1000)
      hash = PasswordService.hash_password(long_password)

      assert is_binary(hash)
      assert String.starts_with?(hash, "$2b$")
    end
  end

  describe "verify_password/2" do
    test "returns true for correct password" do
      password = "correct_password"
      hash = PasswordService.hash_password(password)

      assert PasswordService.verify_password(password, hash) == true
    end

    test "returns false for incorrect password" do
      hash = PasswordService.hash_password("correct_password")

      assert PasswordService.verify_password("wrong_password", hash) == false
    end

    test "returns false for empty password" do
      hash = PasswordService.hash_password("some_password")

      assert PasswordService.verify_password("", hash) == false
    end

    test "returns false for nil password" do
      hash = PasswordService.hash_password("some_password")

      assert PasswordService.verify_password(nil, hash) == false
    end

    test "returns false for nil hash" do
      assert PasswordService.verify_password("password", nil) == false
    end

    test "returns false for both nil" do
      assert PasswordService.verify_password(nil, nil) == false
    end

    test "returns false for non-binary password" do
      hash = PasswordService.hash_password("password")

      assert PasswordService.verify_password(123, hash) == false
      assert PasswordService.verify_password(~c"pass", hash) == false
    end

    test "handles unicode password verification" do
      password = "пароль密码🔐"
      hash = PasswordService.hash_password(password)

      assert PasswordService.verify_password(password, hash) == true
      assert PasswordService.verify_password("different", hash) == false
    end

    test "is case-sensitive" do
      hash = PasswordService.hash_password("Password123")

      assert PasswordService.verify_password("Password123", hash) == true
      assert PasswordService.verify_password("password123", hash) == false
      assert PasswordService.verify_password("PASSWORD123", hash) == false
    end
  end

  describe "no_user_verify/0" do
    test "always returns false" do
      assert PasswordService.no_user_verify() == false
    end

    test "can be called multiple times" do
      assert PasswordService.no_user_verify() == false
      assert PasswordService.no_user_verify() == false
      assert PasswordService.no_user_verify() == false
    end
  end

  describe "timing attack prevention" do
    test "no_user_verify takes measurable time" do
      # This test verifies that no_user_verify does actual work
      # (i.e., it's not just returning false immediately)
      start = System.monotonic_time(:microsecond)
      PasswordService.no_user_verify()
      elapsed = System.monotonic_time(:microsecond) - start

      # Bcrypt's no_user_verify should take at least some time
      # (typically similar to a real hash verification)
      # We just verify it's not instantaneous (> 1ms)
      assert elapsed > 1000
    end
  end
end
