defmodule Agents.Pipeline.Application.UseCases.CreatePullRequest do
  @moduledoc "Creates an internal pull request artifact."

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Entities.PullRequest

  @spec execute(map(), keyword()) :: {:ok, PullRequest.t()} | {:error, term()}
  def execute(attrs, opts \\ []) when is_map(attrs) do
    repo_module =
      Keyword.get(opts, :pull_request_repo, PipelineRuntimeConfig.pull_request_repository())

    attrs =
      attrs
      |> Map.put_new(:status, "draft")

    with {:ok, schema} <- repo_module.create_pull_request(attrs) do
      {:ok, PullRequest.from_schema(schema)}
    end
  end
end
