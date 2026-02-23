defmodule Webhooks.Domain.Policies.HmacPolicy do
  @moduledoc """
  Pure HMAC-SHA256 signature computation and verification policy.

  Provides functions to compute and validate webhook signatures
  using HMAC-SHA256. Uses timing-safe comparison to prevent
  timing attacks.
  """

  @doc """
  Computes an HMAC-SHA256 signature for the given secret and payload.

  Returns a lowercase hex-encoded string (64 characters).
  """
  @spec compute_signature(String.t(), String.t()) :: String.t()
  def compute_signature(secret, payload) do
    :crypto.mac(:hmac, :sha256, secret, payload)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Validates a signature against the expected HMAC-SHA256 digest.

  Uses `Plug.Crypto.secure_compare/2` for timing-safe comparison
  to prevent timing attacks.

  Returns false for nil or empty signatures.
  """
  @spec valid_signature?(String.t(), String.t(), String.t() | nil) :: boolean()
  def valid_signature?(_secret, _payload, nil), do: false
  def valid_signature?(_secret, _payload, ""), do: false

  def valid_signature?(secret, payload, signature) do
    expected = compute_signature(secret, payload)
    Plug.Crypto.secure_compare(expected, signature)
  end
end
