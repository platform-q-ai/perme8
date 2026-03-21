defmodule AgentsWeb.DashboardLive.Components.PipelineKanbanComponents do
  @moduledoc "Function components for the sessions dashboard pipeline kanban row."

  use Phoenix.Component

  import AgentsWeb.CoreComponents

  attr(:kanban, :map, required: true)
  attr(:collapsed, :boolean, required: true)
  attr(:collapsed_columns, :any, required: true)
  attr(:active_ticket_number, :integer, default: nil)

  def pipeline_kanban(assigns) do
    ~H"""
    <section
      id="pipeline-kanban"
      data-testid="pipeline-kanban"
      class="border-t border-base-300 bg-base-100/95 backdrop-blur-sm"
    >
      <div class="flex items-center gap-3 px-3 py-2 border-b border-base-300/70">
        <div>
          <div class="text-[0.65rem] font-semibold uppercase tracking-[0.24em] text-base-content/50">
            Pipeline
          </div>
          <div class="text-xs text-base-content/55">
            {Enum.reduce(@kanban.stages, 0, fn stage, acc -> acc + stage.count end)} active tickets
          </div>
        </div>
        <button
          type="button"
          phx-click="toggle_pipeline_kanban"
          class="btn btn-ghost btn-xs ml-auto"
          data-testid="toggle-pipeline-kanban"
        >
          <.icon
            name={if @collapsed, do: "hero-arrows-pointing-out", else: "hero-arrows-pointing-in"}
            class="size-3.5"
          />
          {if @collapsed, do: "Expand pipeline", else: "Collapse pipeline"}
        </button>
      </div>

      <%= if @collapsed do %>
        <.kanban_status_bar stages={@kanban.stages} />
      <% else %>
        <div class="overflow-x-auto">
          <div class="flex gap-3 px-3 py-3 min-w-max">
            <.kanban_column
              :for={stage <- @kanban.stages}
              stage={stage}
              collapsed={MapSet.member?(@collapsed_columns, stage.id)}
              active_ticket_number={@active_ticket_number}
            />
          </div>
        </div>
      <% end %>
    </section>
    """
  end

  attr(:stage, :map, required: true)
  attr(:collapsed, :boolean, required: true)
  attr(:active_ticket_number, :integer, default: nil)

  def kanban_column(assigns) do
    ~H"""
    <section
      class="w-64 shrink-0 rounded-xl border border-base-300/80 bg-base-200/40"
      data-testid={"kanban-column-#{@stage.id}"}
    >
      <div class="flex items-center gap-2 px-3 py-2 border-b border-base-300/70">
        <span
          class={status_dot_classes(@stage.aggregate_status)}
          data-testid={"kanban-stage-status-#{@stage.id}"}
        >
        </span>
        <div class="min-w-0 flex-1">
          <div class="text-sm font-semibold truncate" data-testid={"kanban-stage-label-#{@stage.id}"}>
            {@stage.label}
          </div>
          <div class="text-[0.7rem] uppercase tracking-[0.2em] text-base-content/45">
            {@stage.aggregate_status}
          </div>
        </div>
        <span class="badge badge-sm badge-neutral" data-testid={"kanban-stage-count-#{@stage.id}"}>
          {@stage.count}
        </span>
      </div>

      <%= cond do %>
        <% @stage.count == 0 -> %>
          <div class="px-3 py-6 text-xs text-base-content/40">No tickets in this stage</div>
        <% @stage.count > 1 and @collapsed -> %>
          <button
            type="button"
            phx-click="toggle_kanban_column"
            phx-value-stage-id={@stage.id}
            class="w-full px-3 py-3 text-left hover:bg-base-300/20 transition-colors"
            data-testid={"kanban-column-toggle-#{@stage.id}"}
          >
            <div class="flex items-center gap-2 text-sm font-medium">
              <.icon name="hero-chevron-right-mini" class="size-4 text-base-content/50" />
              <span>{@stage.count} in {@stage.label}</span>
            </div>
            <div class="text-xs text-base-content/45 mt-1">Expand to inspect ticket cards</div>
          </button>
        <% true -> %>
          <div class="p-2 flex flex-col gap-2">
            <%= if @stage.count > 1 do %>
              <button
                type="button"
                phx-click="toggle_kanban_column"
                phx-value-stage-id={@stage.id}
                class="btn btn-ghost btn-xs justify-start"
                data-testid={"kanban-column-toggle-#{@stage.id}"}
              >
                <.icon name="hero-chevron-down-mini" class="size-4" />
                {@stage.count} in {@stage.label}
              </button>
            <% end %>

            <.kanban_ticket_card
              :for={ticket <- @stage.tickets}
              ticket={ticket}
              active={ticket.number == @active_ticket_number}
            />
          </div>
      <% end %>
    </section>
    """
  end

  attr(:ticket, :map, required: true)
  attr(:active, :boolean, default: false)

  def kanban_ticket_card(assigns) do
    ~H"""
    <div
      data-testid={"build-ticket-item-#{@ticket.number}"}
      data-slot-state={legacy_slot_state(@ticket.status)}
    >
      <div class="flex overflow-hidden rounded-lg border border-base-300 bg-base-100">
        <button
          type="button"
          phx-click="select_kanban_ticket"
          phx-value-number={@ticket.number}
          class={[
            "flex-1 px-3 py-2 text-left transition-colors",
            if(@active, do: "bg-primary/10", else: "hover:bg-base-200")
          ]}
          data-testid={"kanban-ticket-card-#{@ticket.number}"}
        >
          <div class="flex items-start gap-2">
            <span class={status_dot_classes(@ticket.status)}></span>
            <div class="min-w-0 flex-1">
              <div class="text-xs font-semibold text-base-content/70">##{@ticket.number}</div>
              <div class="text-sm leading-snug text-base-content truncate">{@ticket.title}</div>
              <div :if={@ticket.labels != []} class="mt-1 flex flex-wrap gap-1">
                <span
                  :for={label <- Enum.take(@ticket.labels, 2)}
                  class="badge badge-xs badge-outline"
                >
                  {label}
                </span>
              </div>
            </div>
          </div>
        </button>

        <button
          :if={show_pause_ticket?(@ticket.status, @ticket.task_id)}
          type="button"
          phx-click="remove_ticket_from_queue"
          phx-value-number={@ticket.number}
          class="w-9 shrink-0 border-l border-base-300 text-base-content/40 hover:bg-warning/10 hover:text-warning"
          data-testid={"pause-ticket-#{@ticket.number}"}
          title="Pause and move to triage"
        >
          <.icon name="hero-pause-solid" class="size-3 mx-auto" />
        </button>
      </div>

      <div :if={@ticket.status == "warming"} class="mt-1 text-xs text-warning animate-pulse">
        Warming...
      </div>
    </div>
    """
  end

  attr(:stages, :list, required: true)

  def kanban_status_bar(assigns) do
    ~H"""
    <div class="flex flex-wrap items-center gap-2 px-3 py-2" data-testid="kanban-status-bar">
      <div
        :for={stage <- @stages}
        class="inline-flex items-center gap-2 rounded-full border border-base-300 bg-base-200/50 px-2.5 py-1 text-xs"
      >
        <span class={status_dot_classes(stage.aggregate_status)}></span>
        <span>{stage.label}</span>
        <span class="badge badge-xs badge-neutral">{stage.count}</span>
      </div>
    </div>
    """
  end

  defp status_dot_classes(status) do
    color =
      case status do
        status when status in ["active", "running", "starting", "pending"] -> "bg-warning"
        status when status in ["queued_warm", "warming"] -> "bg-warning"
        "queued" -> "bg-info"
        "review" -> "bg-primary"
        "done" -> "bg-success"
        "attention" -> "bg-error"
        _ -> "bg-base-content/30"
      end

    ["mt-1 inline-flex size-2.5 shrink-0 rounded-full", color]
  end

  defp legacy_slot_state(status) do
    case status do
      "warming" -> "warming"
      "queued_warm" -> "warm"
      status when status in ["running", "starting", "pending"] -> "used"
      "queued" -> "queued"
      "failed" -> "failed"
      _ -> nil
    end
  end

  defp show_pause_ticket?(status, task_id) do
    is_binary(task_id) and
      status in ["queued", "queued_warm", "warming", "running", "starting", "pending"]
  end
end
