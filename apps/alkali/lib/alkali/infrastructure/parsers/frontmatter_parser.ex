defmodule Alkali.Infrastructure.Parsers.FrontmatterParser do
  @moduledoc """
  Frontmatter parser for extracting YAML metadata from markdown files.
  """

  @behaviour Alkali.Application.Behaviours.FrontmatterParserBehaviour

  @doc """
  Extracts frontmatter YAML and content from a markdown file.
  """
  @impl true
  @spec parse(String.t()) :: {:ok, {map(), String.t()}} | {:error, String.t()}
  def parse("---\n" <> rest) do
    case String.split(rest, "\n---\n", parts: 2) do
      [yaml_part, content] ->
        # Has closing delimiter
        case parse_yaml(yaml_part) do
          {:ok, frontmatter} ->
            {:ok, {frontmatter, String.trim_leading(content, "\n")}}

          {:error, reason} ->
            {:error, reason}
        end

      [yaml_part] ->
        # No closing delimiter - empty frontmatter, content is after ---\n
        {:ok, {%{}, String.trim_leading(yaml_part, "\n")}}
    end
  end

  @impl true
  def parse("---\n") do
    {:ok, {%{}, ""}}
  end

  @impl true
  def parse(content) do
    {:ok, {%{}, content}}
  end

  defp parse_yaml(yaml) do
    yaml = String.trim(yaml)

    if String.match?(yaml, ~r/".*[^"]$/) do
      {:error, "YAML syntax error: Unclosed quote"}
    else
      result = parse_yaml_lines(yaml)

      case result do
        {:error, reason} -> {:error, reason}
        map when is_map(map) -> {:ok, map}
      end
    end
  end

  defp parse_yaml_lines(yaml) do
    lines = String.split(yaml, "\n", trim: true)
    parse_kv(lines, %{})
  end

  defp parse_kv([], acc), do: acc

  defp parse_kv([line | rest], acc) do
    line = String.trim(line)

    cond do
      String.ends_with?(line, ":") and String.starts_with?(line, "metadata:") ->
        {nested, remaining} = parse_nested(rest, %{})
        parse_kv(remaining, Map.put(acc, "metadata", nested))

      String.contains?(line, ":") ->
        [key, value_part] = String.split(line, ":", parts: 2)
        key = String.trim(key)
        value = parse_value(String.trim(value_part))

        # Check for YAML syntax errors in value
        case value do
          {:error, reason} ->
            # Return error tuple instead of continuing
            {:error, reason}

          _ ->
            parse_kv(rest, Map.put(acc, key, value))
        end

      true ->
        parse_kv(rest, acc)
    end
  end

  defp parse_nested([line | rest], acc) do
    cond do
      line == "" or not String.starts_with?(line, "  ") ->
        {acc, [line | rest]}

      String.contains?(line, ":") ->
        trimmed = String.trim(line)
        [key, value_part] = String.split(trimmed, ":", parts: 2)
        key = String.trim_leading(key, " ")
        value = parse_value(String.trim(value_part))
        parse_nested(rest, Map.put(acc, key, value))

      true ->
        parse_nested(rest, acc)
    end
  end

  defp parse_nested([], acc), do: {acc, []}

  defp parse_value("\"" <> rest) do
    String.trim_trailing(rest, "\"")
  end

  defp parse_value("'" <> rest) do
    String.trim_trailing(rest, "'")
  end

  defp parse_value("[" <> rest) do
    content = String.trim_trailing(rest, "]")

    # Check for unclosed bracket
    if String.ends_with?(rest, "]") do
      content
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.map(&parse_value/1)
    else
      # Return error indicator - will be caught in parse_kv
      {:error, "YAML syntax error: Unclosed bracket in list"}
    end
  end

  defp parse_value("true"), do: true
  defp parse_value("false"), do: false
  defp parse_value("null"), do: nil

  defp parse_value(value) do
    case Float.parse(value) do
      {num, ""} -> num
      _ -> value
    end
  end
end
