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
      # Verifies that no_user_verify performs actual work to prevent
      # timing attacks (not just returning false immediately).
      # The threshold is intentionally low (> 100µs) to avoid flaky
      # failures on fast machines or under CI load, while still proving
      # the function does real computational work.
      start = System.monotonic_time(:microsecond)
      PasswordService.no_user_verify()
      elapsed = System.monotonic_time(:microsecond) - start

      assert elapsed > 100,
             "Expected no_user_verify to take >100µs (took #{elapsed}µs). " <>
               "It should perform real work to prevent timing attacks."
    end
  end
end
