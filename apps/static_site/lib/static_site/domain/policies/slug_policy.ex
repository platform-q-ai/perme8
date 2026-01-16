defmodule StaticSite.Domain.Policies.SlugPolicy do
  @moduledoc """
  SlugPolicy defines business rules for generating URL-safe slugs.

  Pure function with no I/O or side effects.
  """

  @doc """
  Generates a URL-safe slug from a title or filename.

  Rules:
  - Converts to lowercase
  - Replaces spaces with hyphens
  - Removes special characters and punctuation
  - Handles unicode (converts accented characters)
  - Collapses multiple hyphens
  - Trims leading/trailing hyphens

  ## Examples

      iex> SlugPolicy.generate_slug("My First Post")
      "my-first-post"

      iex> SlugPolicy.generate_slug("Post: Part 1 (Updated!)")
      "post-part-1-updated"

      iex> SlugPolicy.generate_slug("Café & Résumé")
      "cafe-resume"
  """
  @spec generate_slug(String.t()) :: String.t()
  def generate_slug(text) when is_binary(text) do
    text
    |> String.trim()
    |> String.downcase()
    |> normalize_unicode()
    |> replace_spaces_with_hyphens()
    |> remove_special_characters()
    |> collapse_hyphens()
    |> trim_hyphens()
  end

  # Private Helpers

  # Normalize unicode characters (é -> e, ñ -> n, etc.)
  defp normalize_unicode(text) do
    text
    |> String.normalize(:nfd)
    |> String.replace(~r/[^\x00-\x7F]/u, "")
  end

  defp replace_spaces_with_hyphens(text) do
    String.replace(text, ~r/\s+/, "-")
  end

  defp remove_special_characters(text) do
    # Keep only alphanumeric and hyphens
    String.replace(text, ~r/[^a-z0-9\-]/, "")
  end

  defp collapse_hyphens(text) do
    String.replace(text, ~r/-+/, "-")
  end

  defp trim_hyphens(text) do
    text
    |> String.trim_leading("-")
    |> String.trim_trailing("-")
  end
end
