defmodule Jarga.Webhooks.Domain.Policies.SignaturePolicy do
  @moduledoc """
  Pure policy for HMAC-SHA256 webhook signature operations.

  Uses Erlang's `:crypto` module (stdlib, not I/O) for HMAC computation
  and `Plug.Crypto.secure_compare/2` for timing-safe comparison.

  No I/O, no side effects.
  """

  @doc """
  Signs a payload with a secret using HMAC-SHA256, returning a hex digest.
  """
  @spec sign(String.t(), String.t()) :: String.t()
  def sign(payload, secret) when is_binary(payload) and is_binary(secret) do
    :crypto.mac(:hmac, :sha256, secret, payload)
    |> Base.encode16(case: :lower)
  end

  @doc """
  Verifies a payload against a provided signature using timing-safe comparison.

  Returns `true` if the computed HMAC matches the provided signature.
  """
  @spec verify(String.t(), String.t(), String.t() | nil) :: boolean()
  def verify(_payload, _secret, nil), do: false
  def verify(_payload, _secret, ""), do: false

  def verify(payload, secret, provided_signature) do
    computed = sign(payload, secret)
    Plug.Crypto.secure_compare(computed, provided_signature)
  end

  @doc """
  Builds a signature header value in the format `"sha256=<hex>"`.
  """
  @spec build_signature_header(String.t(), String.t()) :: String.t()
  def build_signature_header(payload, secret) do
    "sha256=#{sign(payload, secret)}"
  end

  @doc """
  Parses a signature header value, extracting the hex digest.

  Returns `{:ok, hex}` for valid `"sha256=<hex>"` format,
  or `{:error, :invalid_format}` otherwise.
  """
  @spec parse_signature_header(String.t() | nil) :: {:ok, String.t()} | {:error, :invalid_format}
  def parse_signature_header(nil), do: {:error, :invalid_format}
  def parse_signature_header(""), do: {:error, :invalid_format}

  def parse_signature_header("sha256=" <> hex) when byte_size(hex) > 0 do
    {:ok, hex}
  end

  def parse_signature_header(_), do: {:error, :invalid_format}
end
