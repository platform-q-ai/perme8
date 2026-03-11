defmodule Agents.Application.Behaviours.GithubTicketClientBehaviour do
  @moduledoc """
  Behaviour for ticket management operations against GitHub issues.
  """

  @callback get_issue(integer(), keyword()) :: {:ok, map()} | {:error, term()}
  @callback list_issues(keyword()) :: {:ok, [map()]} | {:error, term()}
  @callback create_issue(map(), keyword()) :: {:ok, map()} | {:error, term()}
  @callback update_issue(integer(), map(), keyword()) :: {:ok, map()} | {:error, term()}
  @callback close_issue_with_comment(integer(), keyword()) :: {:ok, map()} | {:error, term()}
  @callback add_comment(integer(), String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  @callback add_sub_issue(integer(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
  @callback remove_sub_issue(integer(), integer(), keyword()) :: {:ok, map()} | {:error, term()}
end
