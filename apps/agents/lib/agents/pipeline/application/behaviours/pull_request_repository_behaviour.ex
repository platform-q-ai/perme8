defmodule Agents.Pipeline.Application.Behaviours.PullRequestRepositoryBehaviour do
  @moduledoc false

  @callback create_pull_request(map()) :: {:ok, term()} | {:error, term()}
  @callback get_by_number(integer()) :: {:ok, term()} | {:error, :not_found}
  @callback get_by_linked_ticket(integer()) :: {:ok, term()} | {:error, :not_found}
  @callback list_filtered(keyword()) :: [term()]
  @callback update_pull_request(integer(), map()) :: {:ok, term()} | {:error, term()}
  @callback add_comment(integer(), map()) :: {:ok, term()} | {:error, term()}
  @callback resolve_comment_thread(Ecto.UUID.t(), String.t()) :: {:ok, term()} | {:error, term()}
  @callback add_review(integer(), map()) :: {:ok, term()} | {:error, term()}
end
