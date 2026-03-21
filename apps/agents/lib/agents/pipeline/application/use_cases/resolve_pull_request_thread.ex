defmodule Agents.Pipeline.Application.UseCases.ResolvePullRequestThread do
  @moduledoc "Marks an internal PR review thread as resolved."

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Entities.PullRequest

  @spec execute(integer(), Ecto.UUID.t(), map(), keyword()) ::
          {:ok, PullRequest.t()} | {:error, term()}
  def execute(number, comment_id, attrs, opts \\ [])
      when is_integer(number) and is_binary(comment_id) and is_map(attrs) do
    repo_module =
      Keyword.get(opts, :pull_request_repo, PipelineRuntimeConfig.pull_request_repository())

    actor_id = Map.get(attrs, :actor_id) || Map.get(attrs, "actor_id") || "mcp-system"

    with {:ok, _comment} <- repo_module.resolve_comment_thread(comment_id, actor_id),
         {:ok, updated} <- repo_module.get_by_number(number) do
      {:ok, PullRequest.from_schema(updated)}
    end
  end
end
