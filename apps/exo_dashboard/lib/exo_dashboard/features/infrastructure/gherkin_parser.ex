defmodule ExoDashboard.Features.Infrastructure.GherkinParser do
  @moduledoc """
  Parses Gherkin .feature files using the @cucumber/gherkin npm package via bun.

  Shells out to `bun run parse.mjs`, sending file paths via stdin
  and receiving JSON AST output.
  """

  alias ExoDashboard.Features.Domain.Entities.{Feature, Scenario, Step, Rule}

  @doc """
  Parses a single .feature file and returns a Feature struct.

  Returns `{:ok, %Feature{}}` on success, `{:error, reason}` on failure.
  """
  @spec parse(String.t()) :: {:ok, Feature.t()} | {:error, String.t()}
  def parse(path) do
    if File.exists?(path) do
      run_parser(path)
    else
      {:error, "File not found: #{path}"}
    end
  end

  defp run_parser(path) do
    parser_dir = parser_script_dir()

    case System.cmd("bun", ["run", "parse.mjs", path],
           cd: parser_dir,
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        parse_output(output, path)

      {error_output, _code} ->
        {:error, "Parser failed: #{String.trim(error_output)}"}
    end
  end

  defp parse_output(json_string, path) do
    case Jason.decode(json_string) do
      {:ok, [%{"gherkinDocument" => doc, "error" => nil}]} when not is_nil(doc) ->
        feature = transform_document(doc, path)
        {:ok, feature}

      {:ok, [%{"error" => error}]} when not is_nil(error) ->
        {:error, error}

      {:ok, []} ->
        {:error, "No results returned from parser"}

      {:error, decode_error} ->
        {:error, "JSON decode error: #{inspect(decode_error)}"}
    end
  end

  defp transform_document(%{"feature" => feature_data}, path) do
    tags = extract_tags(feature_data["tags"])

    children =
      (feature_data["children"] || [])
      |> Enum.map(&transform_child/1)
      |> Enum.reject(&is_nil/1)

    Feature.new(
      id: feature_data["id"],
      uri: path,
      name: feature_data["name"],
      description: feature_data["description"],
      tags: tags,
      language: feature_data["language"],
      children: children
    )
  end

  defp transform_child(%{"scenario" => scenario_data}) do
    transform_scenario(scenario_data)
  end

  defp transform_child(%{"rule" => rule_data}) do
    transform_rule(rule_data)
  end

  defp transform_child(%{"background" => _background_data}) do
    # Background steps are context, not displayed as separate entities
    nil
  end

  defp transform_child(_), do: nil

  defp transform_scenario(data) do
    steps =
      (data["steps"] || [])
      |> Enum.map(&transform_step/1)

    examples =
      case data["examples"] do
        list when is_list(list) and list != [] -> list
        _ -> nil
      end

    Scenario.new(
      id: data["id"],
      name: data["name"],
      keyword: data["keyword"],
      description: data["description"],
      tags: extract_tags(data["tags"]),
      steps: steps,
      examples: examples,
      location: data["location"]
    )
  end

  defp transform_rule(data) do
    children =
      (data["children"] || [])
      |> Enum.map(&transform_child/1)
      |> Enum.reject(&is_nil/1)

    Rule.new(
      id: data["id"],
      name: data["name"],
      description: data["description"],
      tags: extract_tags(data["tags"]),
      children: children
    )
  end

  defp transform_step(data) do
    Step.new(
      id: data["id"],
      keyword: data["keyword"],
      keyword_type: data["keywordType"],
      text: data["text"],
      location: data["location"],
      data_table: data["dataTable"],
      doc_string: data["docString"]
    )
  end

  defp extract_tags(nil), do: []
  defp extract_tags([]), do: []

  defp extract_tags(tags) when is_list(tags) do
    Enum.map(tags, fn tag -> tag["name"] end)
  end

  defp parser_script_dir do
    Application.app_dir(:exo_dashboard, "priv/gherkin_parser")
  end
end
