defmodule Jarga.Accounts.Application.Services.ApiKeyTokenServiceTest do
  use ExUnit.Case, async: true

  alias Jarga.Accounts.Application.Services.ApiKeyTokenService

  describe "generate_token/0" do
    test "returns unique token" do
      token1 = ApiKeyTokenService.generate_token()
      token2 = ApiKeyTokenService.generate_token()

      assert token1 != token2
    end

    test "returns cryptographically secure token" do
      token = ApiKeyTokenService.generate_token()

      # Tokens should be 64 characters
      assert String.length(token) == 64

      # Tokens should only contain URL-safe characters (a-z, A-Z, 0-9, -, _)
      assert Regex.match?(~r/^[a-zA-Z0-9\-_]+$/, token)
    end
  end

  describe "hash_token/1" do
    test "returns different value for same input" do
      token = "my-secure-token-12345"

      hash = ApiKeyTokenService.hash_token(token)

      # Hash should be different from original token
      assert hash != token
    end
  end

  describe "verify_token/2" do
    test "returns true for matching token and hash" do
      token = "my-secure-token-12345"
      hash = ApiKeyTokenService.hash_token(token)

      assert ApiKeyTokenService.verify_token(token, hash) == true
    end

    test "returns false for mismatched token and hash" do
      token1 = "my-secure-token-12345"
      token2 = "different-token-67890"
      hash = ApiKeyTokenService.hash_token(token1)

      assert ApiKeyTokenService.verify_token(token2, hash) == false
    end
  end
end
