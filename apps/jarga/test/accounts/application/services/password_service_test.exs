defmodule Jarga.Accounts.Application.Services.PasswordServiceTest do
  use ExUnit.Case, async: true

  alias Jarga.Accounts.Application.Services.PasswordService

  describe "hash_password/1" do
    test "hashes a password using Bcrypt" do
      password = "hello world!"
      hashed = PasswordService.hash_password(password)

      assert is_binary(hashed)
      assert String.starts_with?(hashed, "$2b$")
      assert byte_size(hashed) == 60
    end

    test "generates different hashes for the same password" do
      password = "hello world!"
      hash1 = PasswordService.hash_password(password)
      hash2 = PasswordService.hash_password(password)

      assert hash1 != hash2
    end

    test "raises for nil password" do
      assert_raise FunctionClauseError, fn ->
        PasswordService.hash_password(nil)
      end
    end
  end

  describe "verify_password/2" do
    test "returns true for correct password" do
      password = "hello world!"
      hashed = PasswordService.hash_password(password)

      assert PasswordService.verify_password(password, hashed)
    end

    test "returns false for incorrect password" do
      password = "hello world!"
      hashed = PasswordService.hash_password(password)

      refute PasswordService.verify_password("wrong password", hashed)
    end

    test "returns false for nil password" do
      hashed = PasswordService.hash_password("hello world!")

      refute PasswordService.verify_password(nil, hashed)
    end

    test "returns false for nil hashed_password" do
      refute PasswordService.verify_password("hello world!", nil)
    end

    test "returns false for empty password" do
      hashed = PasswordService.hash_password("hello world!")

      refute PasswordService.verify_password("", hashed)
    end
  end

  describe "no_user_verify/0" do
    test "performs dummy verification to prevent timing attacks" do
      # This should complete without error and always return false
      result = PasswordService.no_user_verify()

      refute result
    end

    test "takes roughly the same time as a real verification" do
      password = "hello world!"
      hashed = PasswordService.hash_password(password)

      # Time a real verification
      {real_time, _} = :timer.tc(fn -> PasswordService.verify_password(password, hashed) end)

      # Time a dummy verification
      {dummy_time, _} = :timer.tc(fn -> PasswordService.no_user_verify() end)

      # They should be within same order of magnitude (allow 10x difference for timing variance)
      assert dummy_time > real_time / 10
      assert dummy_time < real_time * 10
    end
  end
end
