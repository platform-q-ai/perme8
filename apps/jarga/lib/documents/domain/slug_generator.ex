defmodule Jarga.Documents.Domain.SlugGenerator do
  @moduledoc """
  Domain service for generating unique document slugs within a workspace.

  This is a pure domain service that handles slug generation logic
  without any infrastructure dependencies.
  """

  @doc """
  Generates a unique slug from a title within a workspace.

  Accepts a uniqueness checker function as a dependency for testability.
  """
  def generate(title, workspace_id, uniqueness_checker, excluding_id \\ nil) do
    title
    |> Slugy.slugify()
    |> String.trim_trailing("-")
    |> ensure_unique(workspace_id, uniqueness_checker, excluding_id)
  end

  defp ensure_unique(slug, workspace_id, uniqueness_checker, excluding_id) do
    case uniqueness_checker.(slug, workspace_id, excluding_id) do
      false ->
        slug

      true ->
        "#{slug}-#{generate_random_suffix()}"
        |> ensure_unique(workspace_id, uniqueness_checker, excluding_id)
    end
  end

  defp generate_random_suffix do
    :crypto.strong_rand_bytes(3)
    |> Base.encode16(case: :lower)
  end
end
