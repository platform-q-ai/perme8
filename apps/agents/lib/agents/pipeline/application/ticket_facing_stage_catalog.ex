defmodule Agents.Pipeline.Application.TicketFacingStageCatalog do
  @moduledoc "Translates pipeline config into the ticket-facing kanban stage catalog."

  alias Agents.Pipeline.Domain.Entities.PipelineConfig
  alias Agents.Tickets.Domain.Policies.TicketLifecyclePolicy

  @pre_pipeline_stage_groups %{
    warm_pool: ["ready", "in_progress", "in_review"]
  }

  @type stage_def :: %{id: String.t(), label: String.t()}

  @spec from_pipeline_config(PipelineConfig.t()) :: [stage_def()]
  def from_pipeline_config(%PipelineConfig{stages: stages}) do
    stages
    |> Enum.flat_map(&stage_group_for/1)
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

  defp stage_def(stage_id) do
    %{id: stage_id, label: TicketLifecyclePolicy.stage_label(stage_id)}
  end
end
