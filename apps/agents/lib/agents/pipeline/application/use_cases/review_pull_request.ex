defmodule Agents.Pipeline.Application.UseCases.ReviewPullRequest do
  @moduledoc "Adds a review decision to an internal pull request."

  alias Agents.Pipeline.Domain.Entities.PullRequest
  alias Agents.Pipeline.Infrastructure.Repositories.PullRequestRepository

  @review_to_status %{
    "approve" => "approved",
    "request_changes" => "in_review",
    "comment" => "in_review"
  }

  @spec execute(integer(), map(), keyword()) :: {:ok, PullRequest.t()} | {:error, term()}
  def execute(number, attrs, opts \\ []) when is_integer(number) and is_map(attrs) do
    repo_module = Keyword.get(opts, :pull_request_repo, PullRequestRepository)

    event = Map.get(attrs, :event) || Map.get(attrs, "event")
    next_status = Map.get(@review_to_status, event)

    if is_nil(next_status) do
      {:error, :invalid_review_event}
    else
      review_attrs = %{
        author_id: Map.get(attrs, :actor_id) || Map.get(attrs, "actor_id") || "mcp-system",
        event: event,
        body: Map.get(attrs, :body) || Map.get(attrs, "body")
      }

      with {:ok, _review} <- repo_module.add_review(number, review_attrs),
           {:ok, _updated} <- repo_module.update_pull_request(number, %{status: next_status}),
           {:ok, reloaded} <- repo_module.get_by_number(number) do
        {:ok, PullRequest.from_schema(reloaded)}
      end
    end
  end
end
