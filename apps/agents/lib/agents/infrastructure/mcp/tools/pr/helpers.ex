defmodule Agents.Infrastructure.Mcp.Tools.Pr.Helpers do
  @moduledoc false

  require Logger

  alias Agents.Pipeline.Domain.Entities.PullRequest

  def get_param(params, key) when is_map(params) and is_atom(key) do
    Map.get(params, key) || Map.get(params, Atom.to_string(key))
  end

  def actor_id(frame) do
    frame.assigns[:user_id] || "mcp-system"
  end

  def format_pull_request(%PullRequest{} = pr) do
    """
    # PR ##{pr.number}

    - Title: #{pr.title}
    - Source: #{pr.source_branch}
    - Target: #{pr.target_branch}
    - Status: #{pr.status}
    - Linked ticket: #{pr.linked_ticket || "(none)"}
    - Comments: #{length(pr.comments)}
    - Reviews: #{length(pr.reviews)}
    """
    |> String.trim()
  end

  def format_summary(%PullRequest{} = pr) do
    "PR ##{pr.number}: #{pr.title} (#{pr.status}) #{pr.source_branch} -> #{pr.target_branch}"
  end

  def format_error(:not_found, context), do: "#{context} not found."
  def format_error(:invalid_transition, _), do: "Invalid pull request status transition."
  def format_error(:invalid_review_event, _), do: "Invalid review event."
  def format_error(:not_mergeable, _), do: "Pull request is not mergeable."

  def format_error(reason, _context) do
    Logger.warning("Unhandled PR tool error: #{inspect(reason)}")
    "An unexpected error occurred."
  end
end
