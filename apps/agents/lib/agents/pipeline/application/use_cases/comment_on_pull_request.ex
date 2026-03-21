defmodule Agents.Pipeline.Application.UseCases.CommentOnPullRequest do
  @moduledoc "Adds a review comment to an internal pull request."

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Entities.PullRequest

  @spec execute(integer(), map(), keyword()) :: {:ok, PullRequest.t()} | {:error, term()}
  def execute(number, attrs, opts \\ []) when is_integer(number) and is_map(attrs) do
    repo_module =
      Keyword.get(opts, :pull_request_repo, PipelineRuntimeConfig.pull_request_repository())

    comment_attrs = %{
      author_id: Map.get(attrs, :actor_id) || Map.get(attrs, "actor_id") || "mcp-system",
      body: Map.get(attrs, :body) || Map.get(attrs, "body"),
      path: Map.get(attrs, :path) || Map.get(attrs, "path"),
      line: Map.get(attrs, :line) || Map.get(attrs, "line")
    }

    with {:ok, _comment} <- repo_module.add_comment(number, comment_attrs),
         {:ok, updated} <- repo_module.get_by_number(number) do
      {:ok, PullRequest.from_schema(updated)}
    end
  end
end
