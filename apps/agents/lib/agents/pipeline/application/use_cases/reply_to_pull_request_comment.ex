defmodule Agents.Pipeline.Application.UseCases.ReplyToPullRequestComment do
  @moduledoc "Adds a threaded reply to an existing internal PR review comment."

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Entities.PullRequest

  @spec execute(integer(), Ecto.UUID.t(), map(), keyword()) ::
          {:ok, PullRequest.t()} | {:error, term()}
  def execute(number, parent_comment_id, attrs, opts \\ [])
      when is_integer(number) and is_binary(parent_comment_id) and is_map(attrs) do
    repo_module =
      Keyword.get(opts, :pull_request_repo, PipelineRuntimeConfig.pull_request_repository())

    comment_attrs = %{
      author_id: Map.get(attrs, :actor_id) || Map.get(attrs, "actor_id") || "mcp-system",
      body: Map.get(attrs, :body) || Map.get(attrs, "body"),
      path: Map.get(attrs, :path) || Map.get(attrs, "path"),
      line: Map.get(attrs, :line) || Map.get(attrs, "line"),
      parent_comment_id: parent_comment_id
    }

    with {:ok, _comment} <- repo_module.add_comment(number, comment_attrs),
         {:ok, updated} <- repo_module.get_by_number(number) do
      {:ok, PullRequest.from_schema(updated)}
    end
  end
end
