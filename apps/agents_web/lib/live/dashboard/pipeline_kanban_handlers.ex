defmodule AgentsWeb.DashboardLive.PipelineKanbanHandlers do
  @moduledoc "Handles pipeline kanban interactions and live updates."

  import Phoenix.Component, only: [assign: 3]

  alias AgentsWeb.DashboardLive.TicketHandlers

  def toggle_pipeline_kanban(_params, socket) do
    {:noreply,
     assign(
       socket,
       :pipeline_kanban_collapsed,
       not Map.get(socket.assigns, :pipeline_kanban_collapsed, false)
     )}
  end

  def toggle_kanban_column(%{"stage-id" => stage_id}, socket) when is_binary(stage_id) do
    collapsed_columns = socket.assigns[:collapsed_kanban_columns] || MapSet.new()

    updated =
      if MapSet.member?(collapsed_columns, stage_id) do
        MapSet.delete(collapsed_columns, stage_id)
      else
        MapSet.put(collapsed_columns, stage_id)
      end

    {:noreply, assign(socket, :collapsed_kanban_columns, updated)}
  end

  def toggle_kanban_column(_params, socket), do: {:noreply, socket}

  def select_kanban_ticket(%{"number" => number} = params, socket) when is_binary(number) do
    TicketHandlers.select_ticket(params, socket)
  end

  def select_kanban_ticket(_params, socket), do: {:noreply, socket}

  def pipeline_stage_changed_event(event, socket) do
    mapped_stage = map_pipeline_stage(event.stage_id)

    socket =
      if is_binary(mapped_stage) do
        update_ticket_for_pipeline_stage(socket, event, mapped_stage)
      else
        socket
      end

    {:noreply, socket}
  end

  defp update_ticket_for_pipeline_stage(socket, event, mapped_stage) do
    transitioned_at = event.occurred_at || DateTime.utc_now() |> DateTime.truncate(:second)

    tickets =
      map_ticket_tree(socket.assigns.tickets, fn ticket ->
        if pipeline_ticket_match?(ticket, event) do
          %{ticket | lifecycle_stage: mapped_stage, lifecycle_stage_entered_at: transitioned_at}
        else
          ticket
        end
      end)

    assign(socket, :tickets, tickets)
  end

  defp pipeline_ticket_match?(ticket, event) do
    (is_binary(event.task_id) and Map.get(ticket, :associated_task_id) == event.task_id) or
      (is_binary(event.session_id) and Map.get(ticket, :session_id) == event.session_id)
  end

  defp map_pipeline_stage(stage_id) do
    case stage_id do
      "warm-pool" -> "in_progress"
      "test" -> "ci_testing"
      "deploy" -> "deployed"
      other when other in ["ready", "in_progress", "in_review", "ci_testing", "deployed"] -> other
      _ -> nil
    end
  end

  defp map_ticket_tree(tickets, fun) do
    Enum.map(tickets, fn ticket ->
      ticket = fun.(ticket)
      sub_tickets = map_ticket_tree(Map.get(ticket, :sub_tickets) || [], fun)
      %{ticket | sub_tickets: sub_tickets}
    end)
  end
end
