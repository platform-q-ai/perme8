defmodule Agents.Pipeline.Application.UseCases.ClosePullRequest do
  @moduledoc "Closes an internal pull request without merging."

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Entities.PullRequest

  @spec execute(integer(), keyword()) :: {:ok, PullRequest.t()} | {:error, term()}
  def execute(number, opts \\ []) when is_integer(number) do
    repo_module =
      Keyword.get(opts, :pull_request_repo, PipelineRuntimeConfig.pull_request_repository())

    with {:ok, closed} <-
           repo_module.update_pull_request(number, %{
             status: "closed",
             closed_at: DateTime.utc_now() |> DateTime.truncate(:second)
           }) do
      {:ok, PullRequest.from_schema(closed)}
    end
  end
end
