defmodule Alkali.Infrastructure.CryptoService do
  @moduledoc """
  Infrastructure service for cryptographic operations.

  This module provides cryptographic utilities like hashing,
  keeping these concerns isolated from the domain layer.
  """

  @doc """
  Calculates SHA256 fingerprint from content.

  Returns a 64-character hexadecimal string (lowercase).

  ## Examples

      iex> CryptoService.sha256_fingerprint("body { margin: 0; }")
      "a1b2c3d4..."
  """
  @spec sha256_fingerprint(binary()) :: String.t()
  def sha256_fingerprint(content) do
    :crypto.hash(:sha256, content)
    |> Base.encode16(case: :lower)
  end
end
