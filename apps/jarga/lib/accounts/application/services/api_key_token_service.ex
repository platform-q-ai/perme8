defmodule Jarga.Accounts.Application.Services.ApiKeyTokenService do
  @moduledoc """
  Service for API key token generation and verification.

  This module provides secure token generation using cryptographically secure
  random bytes and token hashing using Bcrypt (same as password hashing).

  ## Security

  - Tokens are generated using cryptographically secure random bytes
  - Tokens are 64 characters, URL-safe (a-z, A-Z, 0-9, -, _)
  - Tokens are hashed using Bcrypt before storage
  - Hash verification uses constant-time comparison to prevent timing attacks

  """

  @token_length 64

  @doc """
  Generates a cryptographically secure random API key token.

  Tokens are 64 characters, URL-safe for use in HTTP headers.

  ## Returns

  A 64-character URL-safe random string

  ## Examples

      iex> token = ApiKeyTokenService.generate_token()
      iex> String.length(token)
      64

  """
  def generate_token do
    @token_length
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> String.slice(0, @token_length)
  end

  @doc """
  Hashes an API key token using SHA256.

  SHA256 is used for API key hashing because:
  1. API keys are randomly generated with high entropy (64 bytes)
  2. We need to be able to look up keys by their hash
  3. Unlike passwords, API keys don't need bcrypt's slow hashing

  ## Parameters

    - `token` - The plain text API key token

  ## Returns

  The SHA256 hash of the token (64 hex characters)

  ## Examples

      iex> hash = ApiKeyTokenService.hash_token("my-token")
      iex> String.length(hash)
      64

  """
  def hash_token(token) when is_binary(token) do
    :crypto.hash(:sha256, token)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Verifies a token against a hash.

  Uses constant-time comparison to prevent timing attacks.

  ## Parameters

    - `token` - The plain text API key token
    - `hash` - The stored SHA256 hash

  ## Returns

  Boolean indicating if token matches hash

  ## Examples

      iex> hash = ApiKeyTokenService.hash_token("my-token")
      iex> ApiKeyTokenService.verify_token("my-token", hash)
      true

      iex> ApiKeyTokenService.verify_token("wrong-token", hash)
      false

  """
  def verify_token(token, hash) when is_binary(token) and is_binary(hash) do
    computed_hash = hash_token(token)
    Plug.Crypto.secure_compare(computed_hash, hash)
  end
end
