defmodule Agents.Pipeline.Application.UseCases.LoadPipeline do
  @moduledoc """
  Loads and validates a pipeline YAML file.
  """

  alias Agents.Pipeline.Application.PipelineRuntimeConfig

  @default_path "perme8-pipeline.yml"

  @doc "Loads and validates the configured pipeline definition file."
  @spec execute(Path.t(), keyword()) ::
          {:ok, Agents.Pipeline.Domain.Entities.PipelineConfig.t()} | {:error, [String.t()]}
  def execute(path \\ @default_path, opts \\ []) when is_binary(path) do
    parser = Keyword.get(opts, :parser, PipelineRuntimeConfig.pipeline_parser())
    parser.parse_file(path)
  end
end
