defmodule Agents.Pipeline.Application.UseCases.GetPullRequest do
  @moduledoc "Gets an internal pull request by number."

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Entities.PullRequest

  @spec execute(integer(), keyword()) :: {:ok, PullRequest.t()} | {:error, :not_found}
  def execute(number, opts \\ []) when is_integer(number) do
    repo_module =
      Keyword.get(opts, :pull_request_repo, PipelineRuntimeConfig.pull_request_repository())

    with {:ok, schema} <- repo_module.get_by_number(number) do
      {:ok, PullRequest.from_schema(schema)}
    end
  end
end
