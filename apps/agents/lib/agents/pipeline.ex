defmodule Agents.Pipeline do
  @moduledoc """
  Public API facade for the Pipeline bounded context.

  Provides the entry point for loading and querying pipeline configuration.
  All pipeline operations should go through this module.
  """

  use Boundary,
    top_level?: true,
    deps: [
      Agents.Pipeline.Domain,
      Agents.Pipeline.Application,
      Agents.Pipeline.Infrastructure
    ],
    exports: []

  alias Agents.Pipeline.Application.UseCases.LoadPipeline

  @doc """
  Loads and validates the pipeline configuration.

  ## Options

    * `:source` - `:string` or `:file` (default: `:file`)
    * `:input` - the YAML string (when source is `:string`)
    * `:path` - file path (default: `"perme8-pipeline.yml"` in project root)
    * `:file_reader` - file reader function (default: `&File.read/1`)

  ## Examples

      iex> Agents.Pipeline.load_pipeline(source: :file, path: "perme8-pipeline.yml")
      {:ok, %Agents.Pipeline.Domain.Entities.PipelineConfig{}}

      iex> Agents.Pipeline.load_pipeline(source: :string, input: yaml_string)
      {:ok, %Agents.Pipeline.Domain.Entities.PipelineConfig{}}
  """
  @spec load_pipeline(keyword()) ::
          {:ok, Agents.Pipeline.Domain.Entities.PipelineConfig.t()} | {:error, term()}
  def load_pipeline(opts \\ []), do: LoadPipeline.execute(opts)
end
