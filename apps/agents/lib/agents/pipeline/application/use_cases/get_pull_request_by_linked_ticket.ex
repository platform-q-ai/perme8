defmodule Agents.Pipeline.Application.UseCases.GetPullRequestByLinkedTicket do
  @moduledoc "Gets an internal pull request by linked ticket number."

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Entities.PullRequest

  @spec execute(integer(), keyword()) :: {:ok, PullRequest.t()} | {:error, :not_found}
  def execute(ticket_number, opts \\ []) when is_integer(ticket_number) do
    repo_module =
      Keyword.get(opts, :pull_request_repo, PipelineRuntimeConfig.pull_request_repository())

    with {:ok, schema} <- repo_module.get_by_linked_ticket(ticket_number) do
      {:ok, PullRequest.from_schema(schema)}
    end
  end
end
