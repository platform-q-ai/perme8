defmodule AgentsWeb.DashboardLive.PipelineKanbanState do
  @moduledoc "Keeps the dashboard's pipeline kanban assign in sync with ticket state."

  import Phoenix.Component, only: [assign: 3]

  alias Agents

  def assign_pipeline_kanban(socket) do
    tickets = socket.assigns[:tickets] || []

    case Agents.get_pipeline_kanban(tickets) do
      {:ok, kanban} -> assign(socket, :pipeline_kanban, kanban)
      {:error, _reason} -> assign(socket, :pipeline_kanban, %{stages: [], generated_at: nil})
    end
  end
end
