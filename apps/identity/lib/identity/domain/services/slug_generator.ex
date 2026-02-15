defmodule Identity.Domain.Services.SlugGenerator do
  @moduledoc """
  Domain service for generating unique workspace slugs.

  This is a pure domain service that handles slug generation logic
  without any infrastructure dependencies.
  """

  @doc """
  Generates a unique slug from a name.

  Accepts a uniqueness checker function as a dependency for testability.
  """
  def generate(name, uniqueness_checker, excluding_id \\ nil) do
    name
    |> Slugy.slugify()
    |> String.trim_trailing("-")
    |> ensure_unique(uniqueness_checker, excluding_id)
  end

  defp ensure_unique(slug, uniqueness_checker, excluding_id) do
    case uniqueness_checker.(slug, excluding_id) do
      false ->
        slug

      true ->
        "#{slug}-#{generate_random_suffix()}" |> ensure_unique(uniqueness_checker, excluding_id)
    end
  end

  defp generate_random_suffix do
    :crypto.strong_rand_bytes(3)
    |> Base.encode16(case: :lower)
  end
end
