defmodule Agents.Pipeline.Application.TicketFacingStageCatalog do
  @moduledoc "Translates pipeline config into the ticket-facing kanban stage catalog."

  alias Agents.Pipeline.Domain.Entities.PipelineConfig
  alias Agents.Tickets.Domain.Policies.TicketLifecyclePolicy

  @pre_pipeline_stage_groups %{
    warm_pool: ["ready", "in_progress", "in_review"]
  }

  @type stage_def :: %{id: String.t(), label: String.t()}

  @spec from_pipeline_config(PipelineConfig.t()) :: [stage_def()]
  def from_pipeline_config(%PipelineConfig{stages: stages, merge_queue: merge_queue}) do
    stage_ids =
      stages
      |> Enum.flat_map(&stage_group_for/1)
      |> maybe_insert_merge_queue(merge_queue)

    stage_ids
    |> Enum.map(&stage_def/1)
    |> Enum.uniq_by(& &1.id)
  end

  defp stage_group_for(%{type: type}) when is_binary(type) do
    case type do
      "warm_pool" -> Map.fetch!(@pre_pipeline_stage_groups, :warm_pool)
      other -> downstream_stage_ids(other)
    end
  end

  defp downstream_stage_ids("verification"), do: ["ci_testing"]
  defp downstream_stage_ids("deploy"), do: ["deployed"]
  defp downstream_stage_ids(_type), do: []

  defp maybe_insert_merge_queue(stage_ids, %{"strategy" => "merge_queue"}) do
    {before, after_or_empty} = Enum.split_while(stage_ids, &(&1 != "ci_testing"))

    case after_or_empty do
      [] -> stage_ids ++ ["merge_queue"]
      ["ci_testing" | rest] -> before ++ ["ci_testing", "merge_queue" | rest]
    end
  end

  defp maybe_insert_merge_queue(stage_ids, _merge_queue), do: stage_ids

  defp stage_def(stage_id) do
    %{id: stage_id, label: TicketLifecyclePolicy.stage_label(stage_id)}
  end
end
