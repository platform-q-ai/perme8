defmodule Agents.Pipeline.Application.UseCases.UpdatePullRequest do
  @moduledoc "Updates internal pull request metadata and status transitions."

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Entities.PullRequest
  alias Agents.Pipeline.Domain.Events.PullRequestUpdated
  alias Agents.Pipeline.Domain.Policies.PullRequestPolicy

  @spec execute(integer(), map(), keyword()) :: {:ok, PullRequest.t()} | {:error, term()}
  def execute(number, attrs, opts \\ []) when is_integer(number) and is_map(attrs) do
    repo_module =
      Keyword.get(opts, :pull_request_repo, PipelineRuntimeConfig.pull_request_repository())

    event_bus = Keyword.get(opts, :event_bus, PipelineRuntimeConfig.event_bus())

    emit_events? =
      Keyword.get(opts, :emit_events?, PipelineRuntimeConfig.emit_pipeline_events?())

    actor_id = Map.get(attrs, :actor_id) || Map.get(attrs, "actor_id") || "pipeline"

    with {:ok, existing} <- repo_module.get_by_number(number),
         :ok <- maybe_validate_transition(existing.status, attrs),
         {:ok, updated} <- repo_module.update_pull_request(number, attrs) do
      if emit_events? do
        _ =
          event_bus.emit(
            PullRequestUpdated.new(%{
              aggregate_id: to_string(updated.number),
              actor_id: actor_id,
              number: updated.number,
              status: updated.status,
              title: updated.title,
              source_branch: updated.source_branch,
              target_branch: updated.target_branch,
              linked_ticket: updated.linked_ticket,
              changes: attrs
            })
          )
      end

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
