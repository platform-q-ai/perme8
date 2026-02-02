defmodule Alkali.Application.Behaviours.CryptoServiceBehaviour do
  @moduledoc """
  Behaviour for cryptographic operations.

  Defines the contract for services that provide cryptographic utilities
  like hashing, keeping these concerns isolated from the domain layer.
  """

  @doc """
  Calculates SHA256 fingerprint from content.

  Returns a 64-character hexadecimal string (lowercase).

  ## Parameters

    - `content` - Binary content to hash

  ## Returns

  A 64-character lowercase hex string representing the SHA256 hash.
  """
  @callback sha256_fingerprint(binary()) :: String.t()
end
