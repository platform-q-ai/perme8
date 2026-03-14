defmodule Perme8Tools.AffectedApps.MixExsParser do
  @moduledoc """
  Parses mix.exs file content to extract `in_umbrella: true` dependency atoms.

  Uses regex-based parsing rather than `Code.eval_string` for safety and speed.
  Excludes test-only dependencies (those with `only: :test`).
  """

  @doc """
  Extracts in_umbrella dependency atoms from a mix.exs file content string.

  Returns a list of atoms representing the umbrella dependencies declared
  in the file, excluding any that are marked as `only: :test`.

  ## Examples

      iex> content = ~s({:identity, in_umbrella: true})
      iex> Perme8Tools.AffectedApps.MixExsParser.parse_in_umbrella_deps(content)
      [:identity]

      iex> Perme8Tools.AffectedApps.MixExsParser.parse_in_umbrella_deps("")
      []
  """
  @spec parse_in_umbrella_deps(String.t()) :: [atom()]
  def parse_in_umbrella_deps(content) when is_binary(content) do
    # Match dep tuples that contain `in_umbrella: true`
    # Uses the `s` flag so `.` and `\s` match across newlines for multi-line declarations
    ~r/\{:(\w+),\s*in_umbrella:\s*true[^}]*\}/s
    |> Regex.scan(content)
    |> Enum.reject(fn [full_match, _name] ->
      Regex.match?(~r/only:\s*:test/, full_match)
    end)
    |> Enum.map(fn [_full_match, name] -> String.to_atom(name) end)
  end

  def parse_in_umbrella_deps(_), do: []
end
