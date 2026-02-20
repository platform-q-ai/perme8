defmodule ExoDashboard.Features.Infrastructure.FeatureFileScanner do
  @moduledoc """
  Scans the umbrella project for Gherkin .feature files.

  Uses `Path.wildcard/1` to find all `.feature` files under
  `apps/*/test/features/**/*.feature`.
  """

  @doc """
  Scans the umbrella root for .feature files.

  Returns a list of absolute paths to `.feature` files.
  """
  @spec scan() :: [String.t()]
  def scan do
    umbrella_root = find_umbrella_root()
    scan(umbrella_root)
  end

  @doc """
  Scans a given base directory for .feature files.

  Looks for files matching `apps/*/test/features/**/*.feature`
  under the given base path.

  Returns a list of absolute paths.
  """
  @spec scan(String.t()) :: [String.t()]
  def scan(base_path) do
    pattern = Path.join(base_path, "apps/*/test/features/**/*.feature")

    pattern
    |> Path.wildcard()
    |> Enum.sort()
  end

  defp find_umbrella_root do
    # Application.app_dir(:exo_dashboard) => _build/dev/lib/exo_dashboard
    # Need to go up 4 levels to reach the umbrella root
    Application.app_dir(:exo_dashboard)
    |> Path.join("../../../..")
    |> Path.expand()
  end
end
