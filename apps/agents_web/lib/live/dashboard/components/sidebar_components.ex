defmodule AgentsWeb.DashboardLive.Components.SidebarComponents do
  @moduledoc """
  Function components for the dashboard left panel (session list sidebar).

  Extracted from the main `index.html.heex` template to reduce its size.
  These are pure structural extractions — no behaviour changes.
  """
  use Phoenix.Component

  import AgentsWeb.CoreComponents
  import AgentsWeb.DashboardLive.Components.SessionComponents
  import AgentsWeb.DashboardLive.Helpers

  alias Agents.Tickets.Domain.Entities.Ticket
  alias AgentsWeb.DashboardLive.Helpers.TicketDataHelpers

  # -- Sidebar Header --

  @doc """
  Renders the sidebar header: new ticket textarea and auth refresh button.
  """
  attr(:syncing_tickets, :boolean, required: true)
  attr(:auth_refreshing, :map, required: true)
  attr(:sessions, :list, required: true)
  attr(:tickets, :list, required: true)

  def sidebar_header(assigns) do
    ~H"""
    <div class="p-3 border-b border-base-300 flex flex-col gap-1.5">
      <form id="sidebar-new-ticket-form" phx-submit="create_ticket" class="w-full">
        <div id="sidebar-new-ticket-input-wrap" phx-update="ignore">
          <textarea
            id="sidebar-new-ticket-instruction"
            name="body"
            rows="2"
            phx-hook="SessionForm"
            data-draft-key="sidebar-new-ticket"
            class="textarea textarea-bordered w-full text-sm leading-snug"
            placeholder="Add a ticket..."
          ></textarea>
        </div>
      </form>
      <button
        :if={has_auth_refresh_candidates?(@sessions)}
        type="button"
        phx-click="refresh_all_auth"
        disabled={@auth_refreshing != %{}}
        class="btn btn-warning btn-sm btn-outline w-full"
      >
        <.icon
          name="hero-arrow-path"
          class={if(@auth_refreshing != %{}, do: "size-4 animate-spin", else: "size-4")}
        />
        {if @auth_refreshing != %{},
          do: "Refreshing #{map_size(@auth_refreshing)}...",
          else: "Refresh All Auth"}
      </button>
    </div>
    """
  end

  # -- Search and Filter --

  @doc """
  Renders the search input and status filter pills.
  """
  attr(:session_search, :string, required: true)
  attr(:status_filter, :atom, required: true)

  def search_and_filter(assigns) do
    ~H"""
    <div class="px-2 pt-2 pb-1 flex flex-col gap-1.5 shrink-0">
      <form phx-change="session_search" class="w-full">
        <label class="input input-bordered input-sm flex items-center gap-2 w-full">
          <.icon name="hero-magnifying-glass" class="size-3.5 text-base-content/40" />
          <input
            type="text"
            name="session_search"
            value={@session_search}
            placeholder="Search sessions and tickets..."
            phx-debounce="200"
            class="grow bg-transparent text-xs border-none focus:outline-none focus:ring-0 p-0"
          />
          <button
            :if={@session_search != ""}
            type="button"
            phx-click="clear_session_search"
            class="btn btn-ghost btn-xs btn-circle p-0 min-h-0 h-auto"
          >
            <.icon name="hero-x-mark" class="size-3" />
          </button>
        </label>
      </form>
      <div class="flex gap-1 flex-wrap">
        <button
          type="button"
          phx-click="status_filter"
          phx-value-status="open"
          class={[
            "btn btn-xs rounded-full",
            if(@status_filter == :open, do: "btn-neutral", else: "btn-ghost")
          ]}
        >
          Open
        </button>
        <button
          type="button"
          phx-click="status_filter"
          phx-value-status="running"
          class={[
            "btn btn-xs rounded-full",
            if(@status_filter == :running, do: "btn-success", else: "btn-ghost")
          ]}
        >
          Running
        </button>
        <button
          type="button"
          phx-click="status_filter"
          phx-value-status="queued"
          class={[
            "btn btn-xs rounded-full",
            if(@status_filter == :queued, do: "btn-info", else: "btn-ghost")
          ]}
        >
          Queued
        </button>
        <button
          type="button"
          phx-click="status_filter"
          phx-value-status="awaiting_feedback"
          class={[
            "btn btn-xs rounded-full",
            if(@status_filter == :awaiting_feedback, do: "btn-warning", else: "btn-ghost")
          ]}
        >
          Feedback
        </button>
        <button
          type="button"
          phx-click="status_filter"
          phx-value-status="failed"
          class={[
            "btn btn-xs rounded-full",
            if(@status_filter == :failed, do: "btn-error btn-outline", else: "btn-ghost")
          ]}
        >
          Failed
        </button>
        <button
          type="button"
          phx-click="status_filter"
          phx-value-status="completed"
          class={[
            "btn btn-xs rounded-full",
            if(@status_filter == :completed,
              do: "btn-primary btn-outline",
              else: "btn-ghost"
            )
          ]}
        >
          Done
        </button>
        <button
          type="button"
          phx-click="status_filter"
          phx-value-status="cancelled"
          class={[
            "btn btn-xs rounded-full",
            if(@status_filter == :cancelled,
              do: "btn-neutral btn-outline",
              else: "btn-ghost"
            )
          ]}
        >
          Cancelled
        </button>
        <button
          type="button"
          phx-click="status_filter"
          phx-value-status="closed"
          class={[
            "btn btn-xs rounded-full",
            if(@status_filter == :closed, do: "btn-neutral btn-outline", else: "btn-ghost")
          ]}
        >
          Closed
        </button>
      </div>
    </div>
    """
  end

  # -- Triage Column --

  @doc """
  Renders the triage column with non-ticket triage sessions and idle tickets.
  """
  attr(:non_ticket_triage_sessions, :list, required: true)
  attr(:optimistic_queued_sessions, :list, required: true)
  attr(:idle_tickets, :list, required: true)
  attr(:active_ticket_numbers, :any, required: true)
  attr(:active_container_id, :string, default: nil)
  attr(:active_ticket_number, :integer, default: nil)
  attr(:collapsed_parents, :any, required: true)
  attr(:syncing_tickets, :boolean, required: true)
  attr(:container_stats, :map, required: true)
  attr(:session_for_ticket, :any, required: true)
  attr(:session_variant, :any, required: true)
  attr(:session_warming?, :any, required: true)
  attr(:ticket_data_id, :any, required: true)

  def triage_column(assigns) do
    ~H"""
    <div class="min-w-0 h-full min-h-0 pr-1 relative overflow-hidden flex flex-col">
      <div class="pointer-events-none select-none absolute inset-0 flex items-start justify-center pt-1">
        <span
          class="text-[6.25rem] font-black italic uppercase tracking-[0.12em]"
          style="writing-mode: vertical-rl; text-orientation: mixed; transform: rotate(180deg) scaleX(1.08) scaleY(0.94); color: rgba(0,0,0,0.03); text-shadow: 0 1px 1px rgba(0,0,0,0.02);"
        >
          TRIAGE
        </span>
      </div>
      <ul
        id="triage-lane"
        class="p-1 w-full flex-1 min-h-0 overflow-y-auto overflow-x-hidden flex flex-col gap-1 rounded-xl border border-base-300/70 bg-base-200/35 shadow-inner shadow-base-content/5"
        style="display:flex;flex-direction:column;"
        phx-hook="TriageLaneDnd"
      >
        <%!-- Non-ticket triage sessions (completed/cancelled without a ticket) --%>
        <li :for={session <- @non_ticket_triage_sessions} class="w-full">
          <.ticket_card
            variant={@session_variant.(session)}
            session={session}
            warming={@session_warming?.(session)}
            active={session.container_id == @active_container_id}
          />
        </li>

        <li :for={session <- @optimistic_queued_sessions} class="w-full">
          <.ticket_card variant={:optimistic} session={session} active={false} />
        </li>

        <%!-- Sync tickets button when no tickets exist --%>
        <li :if={@idle_tickets == []} class="w-full">
          <div class="mx-1 mt-2 mb-1 border-t border-info/35 flex items-center gap-1.5 pt-1.5">
            <.icon name="hero-ticket" class="size-3 text-info/60" />
            <span class="text-[0.6rem] font-semibold uppercase tracking-wider text-info/60">
              Tickets
            </span>
            <div class="ml-auto">
              <button
                type="button"
                phx-click="sync_tickets"
                disabled={@syncing_tickets}
                class="btn btn-ghost btn-xs px-1"
                title="Sync tickets from GitHub"
              >
                <.icon
                  name="hero-arrow-path"
                  class={"size-3 text-info/60 #{if @syncing_tickets, do: "animate-spin", else: ""}"}
                />
              </button>
            </div>
          </div>
        </li>
        <%!-- Triage tickets divider and draggable ticket list --%>
        <li :if={@idle_tickets != []} class="w-full">
          <div class="mx-1 mt-2 mb-1 border-t border-info/35 flex items-center gap-1.5 pt-1.5">
            <.icon name="hero-ticket" class="size-3 text-info/60" />
            <span class="text-[0.6rem] font-semibold uppercase tracking-wider text-info/60">
              Tickets
            </span>
            <span class="text-[0.6rem] text-base-content/40">
              ({length(TicketDataHelpers.all_tickets(@idle_tickets))})
            </span>
            <div class="ml-auto">
              <button
                type="button"
                phx-click="sync_tickets"
                disabled={@syncing_tickets}
                class="btn btn-ghost btn-xs px-1"
                title="Sync tickets from GitHub"
              >
                <.icon
                  name="hero-arrow-path"
                  class={"size-3 text-info/60 #{if @syncing_tickets, do: "animate-spin", else: ""}"}
                />
              </button>
            </div>
          </div>
        </li>
        <li
          :for={ticket <- @idle_tickets}
          class="w-full"
          data-testid="triage-ticket-item"
          data-ticket-depth="0"
          data-has-subissues={to_string(Ticket.has_sub_tickets?(ticket))}
          data-lifecycle-stage={ticket.lifecycle_stage}
          data-ticket-id={@ticket_data_id.(ticket)}
          data-triage-ticket-item
        >
          <% t_session = @session_for_ticket.(ticket) %>
          <div class="flex items-start gap-1">
            <button
              :if={Ticket.has_sub_tickets?(ticket)}
              type="button"
              phx-click="toggle_parent_collapse"
              phx-value-ticket-id={to_string(ticket.id || ticket.number)}
              data-testid="triage-parent-toggle"
              class="btn btn-ghost btn-xs mt-1 px-1"
            >
              <.icon
                name={
                  if(
                    MapSet.member?(
                      @collapsed_parents,
                      to_string(ticket.id || ticket.number)
                    ),
                    do: "hero-chevron-right-mini",
                    else: "hero-chevron-down-mini"
                  )
                }
                class="size-3"
              />
            </button>
            <div class="flex-1 min-w-0">
              <.ticket_card
                ticket={ticket}
                variant={:triage}
                depth={0}
                session={t_session}
                active={ticket.number == @active_ticket_number}
                container_stats={t_session && Map.get(@container_stats, t_session.container_id)}
              />
            </div>
          </div>

          <div
            :if={
              Ticket.has_sub_tickets?(ticket) and
                not MapSet.member?(
                  @collapsed_parents,
                  to_string(ticket.id || ticket.number)
                )
            }
            data-testid="triage-subticket-list"
            class="mt-1 ml-3 flex flex-col gap-1"
          >
            <div
              :for={
                sub_ticket <-
                  Enum.reject(ticket.sub_tickets, fn st ->
                    MapSet.member?(@active_ticket_numbers, st.number)
                  end)
              }
              class="w-full"
              data-testid="triage-ticket-item"
              data-ticket-depth="1"
              data-lifecycle-stage={sub_ticket.lifecycle_stage}
              data-ticket-id={@ticket_data_id.(sub_ticket)}
              data-triage-ticket-item
            >
              <% sub_session = @session_for_ticket.(sub_ticket) %>
              <.ticket_card
                ticket={sub_ticket}
                variant={:triage}
                depth={1}
                session={sub_session}
                active={sub_ticket.number == @active_ticket_number}
                container_stats={sub_session && Map.get(@container_stats, sub_session.container_id)}
              />
            </div>
          </div>
        </li>
      </ul>
    </div>
    """
  end
end
