defmodule ExoDashboard.Features do
  @moduledoc """
  Public API facade for the Features context.

  Delegates to use cases and infrastructure for feature discovery and parsing.
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Domain.Entities.Feature,
      Domain.Entities.Scenario,
      Domain.Entities.Step,
      Domain.Entities.Rule
    ]

  alias ExoDashboard.Features.Application.UseCases.DiscoverFeatures
  alias ExoDashboard.Features.Infrastructure.{FeatureFileScanner, GherkinParser}

  @doc """
  Discovers all feature files in the umbrella, parses them, and returns
  a catalog grouped by app and adapter type.

  Returns `{:ok, %{apps: %{}, by_adapter: %{}}}`.
  """
  def discover(opts \\ []) do
    DiscoverFeatures.execute(
      Keyword.merge([scanner: FeatureFileScanner, parser: GherkinParser], opts)
    )
  end
end
