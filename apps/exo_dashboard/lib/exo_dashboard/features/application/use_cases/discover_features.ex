defmodule ExoDashboard.Features.Application.UseCases.DiscoverFeatures do
  @moduledoc """
  Use case for discovering and cataloging all BDD feature files.

  Scans the umbrella project for .feature files, parses each one,
  and returns a catalog grouped by app and adapter type.
  """

  alias ExoDashboard.Features.Domain.Policies.AdapterClassifier

  @doc """
  Discovers all feature files and returns a grouped catalog.

  Accepts opts with `:scanner` and `:parser` modules for dependency injection.

  Returns `{:ok, %{apps: %{app_name => [Feature]}, by_adapter: %{adapter => [Feature]}}}`.
  """
  @spec execute(keyword()) :: {:ok, map()}
  def execute(opts \\ []) do
    scanner = Keyword.fetch!(opts, :scanner)
    parser = Keyword.fetch!(opts, :parser)

    paths = scanner.scan()

    features =
      paths
      |> Enum.map(fn path ->
        case parser.parse(path) do
          {:ok, feature} ->
            adapter = AdapterClassifier.classify(path)
            app = AdapterClassifier.app_from_path(path)
            %{feature | adapter: adapter, app: app}

          {:error, _reason} ->
            nil
        end
      end)
      |> Enum.reject(&is_nil/1)

    apps = Enum.group_by(features, & &1.app)

    by_adapter =
      features
      |> Enum.reject(fn f -> f.adapter == :unknown end)
      |> Enum.group_by(& &1.adapter)

    {:ok, %{apps: apps, by_adapter: by_adapter}}
  end
end
