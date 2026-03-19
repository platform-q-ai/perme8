defmodule Agents.Pipeline.Application.UseCases.LoadPipeline do
  @moduledoc """
  Use case: Load and validate the pipeline configuration.

  Orchestrates: read source → parse YAML → validate config → return domain entity.
  Supports loading from a YAML string or from a file path. No domain events
  are emitted (this is a read-only operation). No database interaction.
  """

  alias Agents.Pipeline.Domain.Entities.PipelineConfig
  alias Agents.Pipeline.Domain.Policies.PipelineConfigPolicy
  alias Agents.Pipeline.Infrastructure.YamlParser

  @default_path "perme8-pipeline.yml"

  @doc """
  Loads and validates the pipeline configuration.

  ## Options

    * `:source` - `:string` or `:file` (default: `:file`)
    * `:input` - the YAML string (when source is `:string`)
    * `:path` - file path (default: `"perme8-pipeline.yml"` in project root)
    * `:file_reader` - file reader function (default: `&File.read/1`)

  ## Returns

    * `{:ok, PipelineConfig.t()}` on success
    * `{:error, reason}` on failure (parse error, file not found, or validation error)
  """
  @spec execute(keyword()) :: {:ok, PipelineConfig.t()} | {:error, term()}
  def execute(opts \\ []) do
    source = Keyword.get(opts, :source, :file)

    with {:ok, config} <- load_and_parse(source, opts),
         :ok <- PipelineConfigPolicy.validate(config) do
      {:ok, config}
    end
  end

  defp load_and_parse(:string, opts) do
    input = Keyword.fetch!(opts, :input)
    YamlParser.parse(input)
  end

  defp load_and_parse(:file, opts) do
    path = Keyword.get(opts, :path, default_path())
    file_reader = Keyword.get(opts, :file_reader, &File.read/1)
    YamlParser.parse_file(path, file_reader: file_reader)
  end

  defp default_path do
    case File.cwd() do
      {:ok, cwd} -> Path.join(cwd, @default_path)
      _ -> @default_path
    end
  end
end
