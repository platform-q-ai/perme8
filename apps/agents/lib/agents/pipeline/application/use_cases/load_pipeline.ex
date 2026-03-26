defmodule Agents.Pipeline.Application.UseCases.LoadPipeline do
  @moduledoc """
  Loads and validates the current pipeline configuration.
  """

  alias Agents.Pipeline.Application.PipelineConfigStore

  @doc "Loads and validates the configured pipeline definition."
  @spec execute(Path.t() | nil, keyword()) ::
          {:ok, Agents.Pipeline.Domain.Entities.PipelineConfig.t()} | {:error, [String.t()]}
  def execute(path \\ nil, opts \\ []) when is_nil(path) or is_binary(path) do
    PipelineConfigStore.load(path, opts)
  end
end
