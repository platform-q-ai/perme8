defmodule Agents.Pipeline.Application.UseCases.CreatePullRequest do
  @moduledoc "Creates an internal pull request artifact."

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Domain.Events.PullRequestCreated
  alias Agents.Pipeline.Domain.Entities.PullRequest

  @spec execute(map(), keyword()) :: {:ok, PullRequest.t()} | {:error, term()}
  def execute(attrs, opts \\ []) when is_map(attrs) do
    repo_module =
      Keyword.get(opts, :pull_request_repo, PipelineRuntimeConfig.pull_request_repository())

    event_bus = Keyword.get(opts, :event_bus, PipelineRuntimeConfig.event_bus())

    emit_events? =
      Keyword.get(opts, :emit_events?, PipelineRuntimeConfig.emit_pipeline_events?())

    actor_id = Map.get(attrs, :actor_id) || Map.get(attrs, "actor_id") || "pipeline"

    attrs =
      attrs
      |> Map.put_new(:status, "draft")

    with {:ok, schema} <- repo_module.create_pull_request(attrs) do
      if emit_events? do
        _ =
          event_bus.emit(
            PullRequestCreated.new(%{
              aggregate_id: to_string(schema.number),
              actor_id: actor_id,
              number: schema.number,
              title: schema.title,
              source_branch: schema.source_branch,
              target_branch: schema.target_branch,
              linked_ticket: schema.linked_ticket
            })
          )
      end

      {:ok, PullRequest.from_schema(schema)}
    end
  end
end
