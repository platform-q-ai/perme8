defmodule Agents.Pipeline.Infrastructure.YamlParser do
  @moduledoc """
  Parses and validates the pipeline YAML DSL.
  """

  @behaviour Agents.Pipeline.Application.Behaviours.PipelineParserBehaviour

  alias Agents.Pipeline.Application.PipelineConfigBuilder
  alias Agents.Pipeline.Domain.Entities.PipelineConfig

  @doc "Parses a YAML pipeline document into a validated pipeline config."
  @spec parse_file(Path.t()) :: {:ok, PipelineConfig.t()} | {:error, [String.t()]}
  def parse_file(path) when is_binary(path) do
    with {:ok, parsed} <- decode_file(path) do
      PipelineConfigBuilder.build(parsed)
    end
  end

  @doc "Parses YAML content into a validated pipeline config."
  @spec parse_string(String.t()) :: {:ok, PipelineConfig.t()} | {:error, [String.t()]}
  def parse_string(yaml) when is_binary(yaml) do
    with {:ok, parsed} <- decode_string(yaml) do
      PipelineConfigBuilder.build(parsed)
    end
  end

  defp decode_file(path) do
    case YamlElixir.read_from_file(path) do
      {:ok, data} when is_map(data) -> {:ok, data}
      {:error, reason} -> {:error, ["invalid YAML: #{inspect(reason)}"]}
      data when is_map(data) -> {:ok, data}
      other -> {:error, ["invalid YAML root: expected map, got #{inspect(other)}"]}
    end
  rescue
    error ->
      {:error, ["unable to read YAML file #{path}: #{Exception.message(error)}"]}
  end

  defp decode_string(yaml) do
    case YamlElixir.read_from_string(yaml) do
      {:ok, data} when is_map(data) -> {:ok, data}
      {:error, reason} -> {:error, ["invalid YAML: #{inspect(reason)}"]}
      data when is_map(data) -> {:ok, data}
      other -> {:error, ["invalid YAML root: expected map, got #{inspect(other)}"]}
    end
  rescue
    error ->
      {:error, ["invalid YAML: #{Exception.message(error)}"]}
  end
end
