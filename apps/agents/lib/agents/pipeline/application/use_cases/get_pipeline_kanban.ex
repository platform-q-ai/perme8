defmodule Agents.Pipeline.Application.UseCases.GetPipelineKanban do
  @moduledoc "Builds a ticket-facing kanban model for the sessions dashboard."

  alias Agents.Pipeline.Application.UseCases.LoadPipeline
  alias Agents.Pipeline.Application.TicketFacingStageCatalog

  @active_task_statuses ["pending", "starting", "running", "queued", "awaiting_feedback"]
  @spec execute([map()], keyword()) :: {:ok, map()} | {:error, term()}
  def execute(tickets, opts \\ []) when is_list(tickets) do
    pipeline_path = Keyword.get(opts, :pipeline_path)

    with {:ok, config} <- LoadPipeline.execute(pipeline_path, load_pipeline_opts(opts)) do
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
      status: ticket_status(ticket),
      lifecycle_stage: ticket.lifecycle_stage,
      labels: Map.get(ticket, :labels, []),
      task_id: ticket.associated_task_id,
      session_id: Map.get(ticket, :session_id),
      container_id: ticket.associated_container_id
    }
  end

  defp ticket_status(ticket) do
    session_state = Map.get(ticket, :session_state)
    task_status = Map.get(ticket, :task_status)

    cond do
      is_binary(session_state) and session_state not in ["", "idle"] -> session_state
      is_binary(task_status) and task_status != "" -> task_status
      is_binary(session_state) and session_state != "" -> session_state
      is_binary(ticket.lifecycle_stage) -> ticket.lifecycle_stage
      true -> "idle"
    end
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

  defp load_pipeline_opts(opts) do
    opts
    |> maybe_put(:parser, opts[:pipeline_parser])
    |> maybe_put(:pipeline_source, opts[:pipeline_source])
    |> maybe_put(:pipeline_config_repo, opts[:pipeline_config_repo])
    |> maybe_put(:bootstrap_yaml, opts[:bootstrap_yaml])
  end

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)
end
