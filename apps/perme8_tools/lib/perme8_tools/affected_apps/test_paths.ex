defmodule Perme8Tools.AffectedApps.TestPaths do
  @moduledoc """
  Generates unit test directory paths for affected umbrella apps.
  """

  @doc """
  Returns sorted test directory paths for the given affected apps.

  ## Options

  - `:all_apps?` - if `true`, returns all test paths (empty list means run
    `mix test` without path args, which tests everything)
  """
  @spec unit_test_paths(MapSet.t(atom()), keyword()) :: [String.t()]
  def unit_test_paths(affected_apps, opts \\ []) do
    if Keyword.get(opts, :all_apps?, false) do
      []
    else
      affected_apps
      |> Enum.map(fn app -> "apps/#{app}/test" end)
      |> Enum.sort()
    end
  end

  @doc """
  Generates the full `mix test` command string for the affected apps.

  When `all_apps?` is true, returns simply `"mix test"`.
  When no apps are affected, returns `nil`.
  """
  @spec mix_test_command(MapSet.t(atom()), keyword()) :: String.t() | nil
  def mix_test_command(affected_apps, opts \\ []) do
    if Keyword.get(opts, :all_apps?, false) do
      "mix test"
    else
      paths = unit_test_paths(affected_apps, opts)

      case paths do
        [] -> nil
        paths -> "mix test #{Enum.join(paths, " ")}"
      end
    end
  end
end
