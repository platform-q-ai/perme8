defmodule Agents.Pipeline.Application.UseCases.GetPipelineStatus do
  @moduledoc "Loads a pipeline run by id."

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Entities.PipelineRun

  @spec execute(Ecto.UUID.t(), keyword()) :: {:ok, PipelineRun.t()} | {:error, term()}
  def execute(run_id, opts \\ []) do
    repo_module =
      Keyword.get(opts, :pipeline_run_repo, PipelineRuntimeConfig.pipeline_run_repository())

    with {:ok, run} <- repo_module.get_run(run_id) do
      {:ok, PipelineRun.from_schema(run)}
    end
  end
end
