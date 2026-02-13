defmodule Jarga.Documents.Notes.Domain.ContentHash do
  @moduledoc """
  Computes a deterministic hash of note content for optimistic concurrency control.

  Used by the API to detect stale writes: clients must provide the hash of the
  content they based their changes on. If it doesn't match the server's current
  content hash, the update is rejected with a conflict response.
  """

  @doc """
  Computes a SHA-256 hex digest of the given content.

  `nil` content is treated as empty string so that a newly created document
  (with no content yet) has a stable, predictable hash.

  ## Examples

      iex> compute("Hello world")
      "64ec88ca00b268e5ba1a35678a1b5316d212f4f366b2477232534a8aeca37f3c"

      iex> compute(nil)
      compute("")

  """
  @spec compute(String.t() | nil) :: String.t()
  def compute(nil), do: compute("")

  def compute(content) when is_binary(content) do
    :crypto.hash(:sha256, content) |> Base.encode16(case: :lower)
  end
end
