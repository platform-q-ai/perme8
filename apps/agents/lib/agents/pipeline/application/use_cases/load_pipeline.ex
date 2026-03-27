defmodule Agents.Pipeline.Application.UseCases.LoadPipeline do
  @moduledoc """
  Loads and validates the current pipeline configuration.
  """

  alias Agents.Pipeline.Application.PipelineConfigStore

  @doc "Loads and validates the configured pipeline definition."
  @spec execute(keyword()) ::
          {:ok, Agents.Pipeline.Domain.Entities.PipelineConfig.t()} | {:error, [String.t()]}
  def execute(opts \\ []), do: PipelineConfigStore.load(opts)
end
