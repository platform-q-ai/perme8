defmodule Perme8Tools.AffectedApps.OutputFormatter do
  @moduledoc """
  Formats affected apps results for human-readable or JSON output.
  """

  @doc """
  Formats the result as a JSON string.

  The output is deterministic: app names are sorted alphabetically,
  and all atom keys are converted to strings.
  """
  @spec format_json(map()) :: String.t()
  def format_json(result) do
    %{
      affected_apps: result.affected_apps,
      unit_test_paths: result.unit_test_paths,
      exo_bdd_combos: result.exo_bdd_combos,
      all_apps: result.all_apps?,
      all_exo_bdd: result.all_exo_bdd?,
      mix_test_command: result[:mix_test_command]
    }
    |> Map.update!(:affected_apps, fn apps ->
      apps |> Enum.map(&to_string/1) |> Enum.sort()
    end)
    |> Jason.encode!(pretty: true)
  end

  @doc """
  Formats the result as human-readable text.
  """
  @spec format_human(map()) :: String.t()
  def format_human(result) do
    [
      format_affected_section(result),
      format_unit_test_section(result),
      format_exo_bdd_section(result)
    ]
    |> List.flatten()
    |> Enum.join("\n")
  end

  defp format_affected_section(result) do
    cond do
      result.all_apps? ->
        ["Affected apps: ALL (shared config change)"]

      MapSet.size(result.affected_apps) == 0 ->
        ["No apps affected"]

      true ->
        apps =
          result.affected_apps
          |> Enum.map(&to_string/1)
          |> Enum.sort()
          |> Enum.join(", ")

        ["Affected apps (#{MapSet.size(result.affected_apps)}): #{apps}"]
    end
  end

  defp format_unit_test_section(%{mix_test_command: cmd}) when is_binary(cmd) do
    ["", "Unit tests: #{cmd}"]
  end

  defp format_unit_test_section(%{affected_apps: apps}) do
    if MapSet.size(apps) == 0, do: [], else: ["", "Unit tests: (no apps to test)"]
  end

  defp format_exo_bdd_section(%{exo_bdd_combos: []}) do
    []
  end

  defp format_exo_bdd_section(%{exo_bdd_combos: combos, all_exo_bdd?: all_exo_bdd?}) do
    combo_lines =
      Enum.map(combos, fn c ->
        "  - #{c.config_name} [#{c.domain}] (timeout: #{c.timeout}m)"
      end)

    label =
      if all_exo_bdd?,
        do: "Exo-BDD combos (ALL - framework change):",
        else: "Exo-BDD combos (#{length(combos)}):"

    ["", label | combo_lines]
  end
end
