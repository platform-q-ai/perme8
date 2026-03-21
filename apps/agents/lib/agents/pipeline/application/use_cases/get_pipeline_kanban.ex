defmodule Agents.Pipeline.Application.UseCases.GetPipelineKanban do
  @moduledoc "Builds a ticket-facing kanban model for the sessions dashboard."

  alias Agents.Pipeline.Application.PipelineRuntimeConfig
  alias Agents.Pipeline.Application.TicketFacingStageCatalog

  @active_task_statuses ["pending", "starting", "running", "queued", "awaiting_feedback"]
  @spec execute([map()], keyword()) :: {:ok, map()} | {:error, term()}
  def execute(tickets, opts \\ []) when is_list(tickets) do
    parser = Keyword.get(opts, :pipeline_parser, PipelineRuntimeConfig.pipeline_parser())
    pipeline_path = Keyword.get(opts, :pipeline_path, default_pipeline_path())

    with {:ok, config} <- parser.parse_file(pipeline_path) do
      stage_defs = TicketFacingStageCatalog.from_pipeline_config(config)
      stage_ids = MapSet.new(stage_defs, & &1.id)

      grouped_tickets =
        tickets
        |> flatten_ticket_tree()
        |> Enum.filter(&ticket_in_kanban?(&1, stage_ids))
        |> Enum.group_by(&kanban_stage_id(&1, stage_ids))

      {:ok,
       %{
         stages: Enum.map(stage_defs, &build_stage(&1, Map.get(grouped_tickets, &1.id, []))),
         generated_at: DateTime.utc_now() |> DateTime.truncate(:second)
       }}
    end
  end

  defp build_stage(stage_def, tickets) do
    items = Enum.map(tickets, &ticket_item/1)

    %{
      id: stage_def.id,
      label: stage_def.label,
      count: length(items),
      aggregate_status: aggregate_status(items, stage_def.id),
      tickets: items
    }
  end

  defp ticket_item(ticket) do
    %{
      number: ticket.number,
      title: ticket.title,
      status: ticket.session_state || ticket.task_status || ticket.lifecycle_stage || "idle",
      lifecycle_stage: ticket.lifecycle_stage,
      labels: Map.get(ticket, :labels, []),
      task_id: ticket.associated_task_id,
      session_id: Map.get(ticket, :session_id),
      container_id: ticket.associated_container_id
    }
  end

  defp aggregate_status([], _stage_id), do: "idle"

  defp aggregate_status(items, stage_id) do
    statuses = Enum.map(items, & &1.status)

    cond do
      Enum.any?(statuses, &(&1 == "failed")) -> "attention"
      stage_id == "deployed" -> "done"
      Enum.any?(statuses, &(&1 in ["running", "starting", "pending"])) -> "active"
      Enum.any?(statuses, &(&1 == "queued")) -> "queued"
      stage_id == "in_review" -> "review"
      true -> "steady"
    end
  end

  defp ticket_in_kanban?(ticket, stage_ids) do
    cond do
      Map.get(ticket, :state) == "closed" -> false
      MapSet.member?(stage_ids, kanban_stage_id(ticket, stage_ids)) -> true
      true -> false
    end
  end

  defp kanban_stage_id(ticket, stage_ids) do
    lifecycle_stage = Map.get(ticket, :lifecycle_stage)
    task_status = Map.get(ticket, :task_status)

    cond do
      is_binary(lifecycle_stage) and MapSet.member?(stage_ids, lifecycle_stage) ->
        lifecycle_stage

      task_status in @active_task_statuses and MapSet.member?(stage_ids, "in_progress") ->
        "in_progress"

      true ->
        nil
    end
  end

  defp flatten_ticket_tree(tickets) do
    Enum.flat_map(tickets, fn ticket ->
      [ticket | flatten_ticket_tree(Map.get(ticket, :sub_tickets) || [])]
    end)
  end

  defp default_pipeline_path do
    Path.expand("../../../../../../../perme8-pipeline.yml", __DIR__)
  end
end
