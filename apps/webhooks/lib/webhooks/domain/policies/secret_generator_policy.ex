defmodule Webhooks.Domain.Policies.SecretGeneratorPolicy do
  @moduledoc """
  Pure policy for generating cryptographically secure webhook secrets.

  Uses `:crypto.strong_rand_bytes/1` for entropy and URL-safe Base64
  encoding for the output format.
  """

  @min_length 32

  @doc """
  Generates a cryptographically secure webhook secret.

  Returns a URL-safe Base64 encoded string (no padding) derived
  from 32 bytes of random data.
  """
  @spec generate() :: String.t()
  def generate do
    :crypto.strong_rand_bytes(32)
    |> Base.url_encode64(padding: false)
  end

  @doc """
  Returns true if the given secret meets the minimum length requirement.

  Secrets must be at least #{@min_length} characters long.
  """
  @spec sufficient_length?(String.t()) :: boolean()
  def sufficient_length?(secret) when is_binary(secret) do
    String.length(secret) >= @min_length
  end
end
