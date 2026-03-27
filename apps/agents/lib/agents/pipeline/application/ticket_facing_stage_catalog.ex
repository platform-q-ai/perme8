defmodule Agents.Pipeline.Application.TicketFacingStageCatalog do
  @moduledoc "Translates pipeline config into the ticket-facing kanban stage catalog."

  alias Agents.Pipeline.Domain.Entities.PipelineConfig
  alias Agents.Tickets.Domain.Policies.TicketLifecyclePolicy

  @ticket_entry_stage_groups ["ready", "in_progress", "in_review"]

  @type stage_def :: %{
          id: String.t(),
          label: String.t(),
          ticket_concurrency: non_neg_integer() | nil
        }

  @spec from_pipeline_config(PipelineConfig.t()) :: [stage_def()]
  def from_pipeline_config(%PipelineConfig{stages: stages}) do
    stages
    |> Enum.flat_map(&stage_group_for/1)
    |> Enum.map(&stage_def(&1, stages))
    |> Enum.uniq_by(& &1.id)
  end

  defp stage_group_for(%{id: id, triggers: triggers, type: type})
       when is_binary(id) and is_list(triggers) and is_binary(type) do
    cond do
      "on_ticket_play" in triggers -> @ticket_entry_stage_groups
      id in ["merge-queue", "merge_queue"] -> ["merge_queue"]
      true -> downstream_stage_ids(type)
    end
  end

  defp downstream_stage_ids("verification"), do: ["ci_testing"]
  defp downstream_stage_ids("automation"), do: ["deployed"]
  defp downstream_stage_ids(_type), do: []

  defp stage_def(stage_id, stages) do
    %{
      id: stage_id,
      label: TicketLifecyclePolicy.stage_label(stage_id),
      ticket_concurrency: ticket_concurrency_for(stage_id, stages)
    }
  end

  defp ticket_concurrency_for("ci_testing", stages),
    do: stage_concurrency_by_type(stages, "verification")

  defp ticket_concurrency_for("deployed", stages),
    do: stage_concurrency_by_type(stages, "automation")

  defp ticket_concurrency_for("merge_queue", stages),
    do:
      stage_concurrency_by_id(stages, "merge-queue") ||
        stage_concurrency_by_id(stages, "merge_queue")

  defp ticket_concurrency_for(_stage_id, _stages), do: nil

  defp stage_concurrency_by_id(stages, id) do
    stages
    |> Enum.find(&(&1.id == id))
    |> case do
      nil -> nil
      stage -> stage.ticket_concurrency
    end
  end

  defp stage_concurrency_by_type(stages, type) do
    stages
    |> Enum.find(&(&1.type == type))
    |> case do
      nil -> nil
      stage -> stage.ticket_concurrency
    end
  end
end
