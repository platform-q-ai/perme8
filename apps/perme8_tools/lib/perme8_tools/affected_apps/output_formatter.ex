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
    sections = []

    sections =
      cond do
        result.all_apps? ->
          sections ++ ["Affected apps: ALL (shared config change)"]

        MapSet.size(result.affected_apps) == 0 ->
          sections ++ ["No apps affected"]

        true ->
          apps =
            result.affected_apps
            |> Enum.map(&to_string/1)
            |> Enum.sort()
            |> Enum.join(", ")

          sections ++ ["Affected apps (#{MapSet.size(result.affected_apps)}): #{apps}"]
      end

    sections =
      if result[:mix_test_command] do
        sections ++ ["", "Unit tests: #{result.mix_test_command}"]
      else
        if MapSet.size(result.affected_apps) == 0 do
          sections
        else
          sections ++ ["", "Unit tests: (no apps to test)"]
        end
      end

    sections =
      case result.exo_bdd_combos do
        [] ->
          if result.all_exo_bdd? do
            sections ++ ["", "Exo-BDD: ALL combos (framework change)"]
          else
            sections
          end

        combos ->
          combo_lines =
            Enum.map(combos, fn c ->
              "  - #{c.config_name} [#{c.domain}] (timeout: #{c.timeout}m)"
            end)

          label =
            if result.all_exo_bdd?,
              do: "Exo-BDD combos (ALL - framework change):",
              else: "Exo-BDD combos (#{length(combos)}):"

          sections ++ ["", label | combo_lines]
      end

    Enum.join(sections, "\n")
  end
end
