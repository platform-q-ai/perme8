defmodule ExoDashboard.Features.Domain.Policies.AdapterClassifier do
  @moduledoc """
  Pure policy that classifies feature files by adapter type
  based on filename conventions.

  Convention: `<name>.<adapter>.feature`
  Example: `login.browser.feature` -> `:browser`
  """

  @known_adapters ~w(browser http security cli graph)

  @doc """
  Classifies a feature file path or filename into its adapter type.

  Extracts the adapter from the filename pattern `<name>.<adapter>.feature`.
  Returns `:unknown` if no recognized adapter suffix is found.
  """
  @spec classify(String.t()) :: atom()
  def classify(path) do
    filename = Path.basename(path)

    case Regex.run(~r/\.(\w+)\.feature$/, filename) do
      [_, adapter] when adapter in @known_adapters ->
        String.to_existing_atom(adapter)

      _ ->
        :unknown
    end
  end

  @doc """
  Extracts the umbrella app name from a feature file path.

  Expects paths like `apps/<app_name>/test/features/...`.
  Returns `nil` if the path doesn't match the umbrella convention.
  """
  @spec app_from_path(String.t()) :: String.t() | nil
  def app_from_path(path) do
    case Regex.run(~r{apps/([^/]+)/}, path) do
      [_, app_name] -> app_name
      _ -> nil
    end
  end
end
