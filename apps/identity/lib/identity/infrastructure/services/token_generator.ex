defmodule Identity.Infrastructure.Services.TokenGenerator do
  @moduledoc """
  Infrastructure service for cryptographic token generation.

  This service encapsulates all cryptographic operations for token generation,
  keeping the domain layer completely pure with zero infrastructure dependencies.

  ## Security

  - Uses `:crypto.strong_rand_bytes/1` for cryptographically secure random generation
  - Uses SHA256 for token hashing
  - Tokens are URL-safe base64 encoded

  ## Usage

  This service is used by UserToken entity builders to generate secure tokens
  without introducing infrastructure dependencies into the domain layer.
  """

  @behaviour Identity.Application.Behaviours.TokenGeneratorBehaviour

  @hash_algorithm :sha256
  @rand_size 32

  @doc """
  Generates a cryptographically secure random token.

  ## Parameters

  - `size` - Size in bytes (default: 32)

  ## Returns

  Binary token of specified size

  ## Examples

      iex> token = TokenGenerator.generate_random_token()
      iex> byte_size(token)
      32
      
      iex> token = TokenGenerator.generate_random_token(16)
      iex> byte_size(token)
      16
  """
  @impl true
  def generate_random_token(size \\ @rand_size) do
    :crypto.strong_rand_bytes(size)
  end

  @doc """
  Hashes a token using SHA256.

  ## Parameters

  - `token` - Binary token to hash

  ## Returns

  Hashed token as binary

  ## Examples

      iex> token = "my_token"
      iex> hashed = TokenGenerator.hash_token(token)
      iex> is_binary(hashed)
      true
      iex> byte_size(hashed)
      32
  """
  @impl true
  def hash_token(token) do
    :crypto.hash(@hash_algorithm, token)
  end

  @doc """
  Encodes a token for URL-safe transmission.

  ## Parameters

  - `token` - Binary token to encode

  ## Returns

  URL-safe base64 encoded string (without padding)

  ## Examples

      iex> token = <<1, 2, 3>>
      iex> encoded = TokenGenerator.encode_token(token)
      iex> String.valid?(encoded)
      true
  """
  @impl true
  def encode_token(token) do
    Base.url_encode64(token, padding: false)
  end

  @doc """
  Decodes a URL-safe base64 encoded token.

  ## Parameters

  - `encoded_token` - URL-safe base64 string

  ## Returns

  - `{:ok, binary}` if decoding succeeds
  - `:error` if decoding fails

  ## Examples

      iex> {:ok, decoded} = TokenGenerator.decode_token("AQID")
      iex> decoded
      <<1, 2, 3>>
      
      iex> TokenGenerator.decode_token("invalid!!!")
      :error
  """
  @impl true
  def decode_token(encoded_token) do
    Base.url_decode64(encoded_token, padding: false)
  end

  @doc """
  Returns the configured random token size in bytes.

  ## Examples

      iex> TokenGenerator.rand_size()
      32
  """
  @impl true
  def rand_size, do: @rand_size

  @doc """
  Returns the hash algorithm used for token hashing.

  ## Examples

      iex> TokenGenerator.hash_algorithm()
      :sha256
  """
  def hash_algorithm, do: @hash_algorithm
end
