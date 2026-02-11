defmodule Identity.Application.Services.ApiKeyTokenServiceTest do
  @moduledoc """
  Unit tests for the ApiKeyTokenService application service.

  These tests verify API key token generation, hashing, and verification.
  """

  use ExUnit.Case, async: true

  alias Identity.Application.Services.ApiKeyTokenService

  describe "generate_token/0" do
    test "generates a 64-character token" do
      token = ApiKeyTokenService.generate_token()

      assert String.length(token) == 64
    end

    test "generates URL-safe tokens" do
      token = ApiKeyTokenService.generate_token()

      # URL-safe base64 characters: a-z, A-Z, 0-9, -, _
      assert String.match?(token, ~r/^[A-Za-z0-9_-]+$/)
    end

    test "generates unique tokens each time" do
      token1 = ApiKeyTokenService.generate_token()
      token2 = ApiKeyTokenService.generate_token()
      token3 = ApiKeyTokenService.generate_token()

      refute token1 == token2
      refute token2 == token3
      refute token1 == token3
    end

    test "tokens are cryptographically random" do
      # Generate many tokens and verify they have good entropy
      tokens = for _ <- 1..100, do: ApiKeyTokenService.generate_token()

      # All tokens should be unique
      assert length(Enum.uniq(tokens)) == 100

      # No obvious patterns - check character distribution isn't skewed
      all_chars = tokens |> Enum.join() |> String.graphemes()
      unique_chars = Enum.uniq(all_chars)

      # Should use a good variety of the URL-safe base64 alphabet
      assert length(unique_chars) > 50
    end
  end

  describe "hash_token/1" do
    test "returns a 64-character hex string" do
      token = "test_token"
      hash = ApiKeyTokenService.hash_token(token)

      assert String.length(hash) == 64
      assert String.match?(hash, ~r/^[a-f0-9]+$/)
    end

    test "same token always produces same hash" do
      token = "consistent_token"

      hash1 = ApiKeyTokenService.hash_token(token)
      hash2 = ApiKeyTokenService.hash_token(token)

      assert hash1 == hash2
    end

    test "different tokens produce different hashes" do
      hash1 = ApiKeyTokenService.hash_token("token_one")
      hash2 = ApiKeyTokenService.hash_token("token_two")

      refute hash1 == hash2
    end

    test "small changes in token produce completely different hashes" do
      hash1 = ApiKeyTokenService.hash_token("token_a")
      hash2 = ApiKeyTokenService.hash_token("token_b")

      # Count differing characters
      diff_count =
        Enum.zip(String.graphemes(hash1), String.graphemes(hash2))
        |> Enum.count(fn {a, b} -> a != b end)

      # SHA256 avalanche effect - small input change should change ~50% of output
      assert diff_count > 20
    end

    test "handles empty string" do
      hash = ApiKeyTokenService.hash_token("")

      assert String.length(hash) == 64
      assert String.match?(hash, ~r/^[a-f0-9]+$/)
    end

    test "handles unicode tokens" do
      hash = ApiKeyTokenService.hash_token("токен🔑")

      assert String.length(hash) == 64
      assert String.match?(hash, ~r/^[a-f0-9]+$/)
    end

    test "handles long tokens" do
      long_token = String.duplicate("x", 10_000)
      hash = ApiKeyTokenService.hash_token(long_token)

      assert String.length(hash) == 64
    end
  end

  describe "verify_token/2" do
    test "returns true for matching token and hash" do
      token = "my_secret_token"
      hash = ApiKeyTokenService.hash_token(token)

      assert ApiKeyTokenService.verify_token(token, hash) == true
    end

    test "returns false for non-matching token" do
      hash = ApiKeyTokenService.hash_token("original_token")

      assert ApiKeyTokenService.verify_token("different_token", hash) == false
    end

    test "is case-sensitive for tokens" do
      token = "CaseSensitiveToken"
      hash = ApiKeyTokenService.hash_token(token)

      assert ApiKeyTokenService.verify_token("CaseSensitiveToken", hash) == true
      assert ApiKeyTokenService.verify_token("casesensitivetoken", hash) == false
      assert ApiKeyTokenService.verify_token("CASESENSITIVETOKEN", hash) == false
    end

    test "works with generated tokens" do
      token = ApiKeyTokenService.generate_token()
      hash = ApiKeyTokenService.hash_token(token)

      assert ApiKeyTokenService.verify_token(token, hash) == true
    end

    test "handles unicode tokens" do
      token = "токен🔑"
      hash = ApiKeyTokenService.hash_token(token)

      assert ApiKeyTokenService.verify_token(token, hash) == true
      assert ApiKeyTokenService.verify_token("другой", hash) == false
    end
  end

  describe "full workflow" do
    test "generate, hash, verify workflow" do
      # 1. Generate a new token
      token = ApiKeyTokenService.generate_token()
      assert String.length(token) == 64

      # 2. Hash it for storage
      hash = ApiKeyTokenService.hash_token(token)
      assert String.length(hash) == 64

      # 3. Verify the original token against the hash
      assert ApiKeyTokenService.verify_token(token, hash) == true

      # 4. Different token should not verify
      other_token = ApiKeyTokenService.generate_token()
      assert ApiKeyTokenService.verify_token(other_token, hash) == false
    end
  end
end
