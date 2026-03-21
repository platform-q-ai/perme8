defmodule Agents.Pipeline.Application.UseCases.UpdatePullRequest do
  @moduledoc "Updates internal pull request metadata and status transitions."

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Entities.PullRequest
  alias Agents.Pipeline.Domain.Policies.PullRequestPolicy

  @spec execute(integer(), map(), keyword()) :: {:ok, PullRequest.t()} | {:error, term()}
  def execute(number, attrs, opts \\ []) when is_integer(number) and is_map(attrs) do
    repo_module =
      Keyword.get(opts, :pull_request_repo, PipelineRuntimeConfig.pull_request_repository())

    with {:ok, existing} <- repo_module.get_by_number(number),
         :ok <- maybe_validate_transition(existing.status, attrs),
         {:ok, updated} <- repo_module.update_pull_request(number, attrs) do
      {:ok, PullRequest.from_schema(updated)}
    end
  end

  defp maybe_validate_transition(_current, %{status: nil}), do: :ok
  defp maybe_validate_transition(_current, %{"status" => nil}), do: :ok
  defp maybe_validate_transition(_current, attrs) when map_size(attrs) == 0, do: :ok

  defp maybe_validate_transition(current, attrs) do
    next = Map.get(attrs, :status) || Map.get(attrs, "status")

    if is_nil(next) or next == current do
      :ok
    else
      PullRequestPolicy.valid_transition?(current, next)
    end
  end
end
