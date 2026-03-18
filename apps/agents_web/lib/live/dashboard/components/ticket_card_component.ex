defmodule AgentsWeb.DashboardLive.Components.TicketCardComponent do
  @moduledoc """
  Ticket card and related display components for the dashboard LiveView.

  Contains the unified board card component (`ticket_card/1`) used across
  triage and build queue columns, plus label picker, lifecycle timeline,
  and all card helper functions.
  """
  use Phoenix.Component

  import AgentsWeb.CoreComponents

  import AgentsWeb.DashboardLive.Components.ChatOutputComponents,
    only: [compact_progress_bar: 1, format_mem_short: 1, render_markdown: 1]

  import AgentsWeb.DashboardLive.Helpers,
    only: [
      ticket_label_class: 1,
      available_labels: 0,
      format_file_stats: 1,
      session_todo_items: 1,
      image_label: 1,
      relative_time: 1,
      slugify: 1,
      truncate_instruction: 2,
      auth_error?: 1,
      auth_refreshing?: 2
    ]

  alias Agents.Tickets.Domain.Entities.Ticket
  alias Agents.Tickets.Domain.Entities.Ticket.View
  alias Agents.Tickets.Domain.Policies.TicketHierarchyPolicy

  # ---- Tab Bar ----

  @doc """
  Renders an accessible tab bar for the session detail panel.

  Each tab is a `role="tab"` button inside a `role="tablist"` container.
  The active tab gets `aria-selected="true"`. Clicking a tab emits a
  `"switch_tab"` event with the tab id.

  ## Assigns

    * `:active_tab` - the id of the currently active tab (string)
    * `:tabs` - list of `%{id: string, label: string}` maps
  """
  attr(:active_tab, :string, required: true)
  attr(:tabs, :list, required: true)

  def tab_bar(assigns) do
    ~H"""
    <div role="tablist" class="flex border-b border-base-300 bg-base-100 shrink-0 px-2 gap-1">
      <button
        :for={tab <- @tabs}
        role="tab"
        type="button"
        data-tab-id={tab.id}
        aria-selected={to_string(tab.id == @active_tab)}
        aria-controls={"tabpanel-#{tab.id}"}
        phx-click="switch_tab"
        phx-value-tab={tab.id}
        class={[
          "px-16 py-2 text-sm font-medium border-b-2 -mb-px transition-colors",
          if(tab.id == @active_tab,
            do: "border-primary text-primary",
            else:
              "border-transparent text-base-content/50 hover:text-base-content/80 hover:border-base-300"
          )
        ]}
      >
        {tab.label}
      </button>
    </div>
    """
  end

  # ---- Question Card ----

  @doc """
  Renders the AI assistant's question with selectable options and a submit button.

  Questions remain active indefinitely until the user answers or dismisses them.
  """
  attr(:pending, :map, required: true)

  def question_card(assigns) do
    ~H"""
    <div class="mt-3 rounded-lg border-2 p-4 border-warning/40 bg-warning/5">
      <div class="flex items-center gap-2 mb-3">
        <.icon name="hero-question-mark-circle" class="size-5 text-warning" />
        <span class="font-semibold text-sm text-warning">
          Question from Assistant
        </span>
      </div>

      <form id="question-form" phx-change="update_question_form" phx-submit="submit_question_answer">
        <%= for {question, q_idx} <- Enum.with_index(@pending.questions) do %>
          <div class={["mb-4", q_idx > 0 && "pt-3 border-t border-base-300/50"]}>
            <div class="text-xs font-semibold text-base-content/60 uppercase tracking-wider mb-1">
              {question["header"]}
            </div>
            <div class="text-sm mb-2 session-markdown">{render_markdown(question["question"])}</div>

            <div :if={question["multiple"]} class="text-[0.65rem] text-base-content/50 mb-1">
              Select one or more options
            </div>

            <div class="flex flex-wrap gap-1.5 mb-2">
              <%= for option <- question["options"] || [] do %>
                <% selected = option["label"] in Enum.at(@pending.selected, q_idx, []) %>
                <button
                  type="button"
                  phx-click="toggle_question_option"
                  phx-value-question-index={q_idx}
                  phx-value-label={option["label"]}
                  class={[
                    "btn btn-sm",
                    if(selected, do: "btn-primary", else: "btn-outline")
                  ]}
                  title={option["description"]}
                >
                  {option["label"]}
                </button>
              <% end %>
            </div>

            <%!-- Custom text input — always available (opencode default) --%>
            <div class="mt-2">
              <input
                type="text"
                name={"custom_answer[#{q_idx}]"}
                placeholder="Type your own answer..."
                value={Enum.at(@pending.custom_text, q_idx, "")}
                phx-debounce="300"
                class="input input-bordered input-sm w-full text-sm"
              />
            </div>
          </div>
        <% end %>

        <div class="flex gap-2 mt-2">
          <button
            type="submit"
            class="btn btn-primary btn-sm"
          >
            <.icon name="hero-check" class="size-4" /> Submit Answer
          </button>
          <button
            type="button"
            phx-click="dismiss_question"
            class="btn btn-ghost btn-sm"
          >
            Dismiss
          </button>
        </div>
      </form>
    </div>
    """
  end

  # ---- Ticket Card ----

  @doc """
  Unified board card component used for both tickets and standalone sessions
  across triage and build queue columns.

  When `ticket` is provided, the card renders ticket metadata (number badge,
  labels, sub-ticket summary) with session decorations based on variant.
  When `ticket` is nil, the card renders from session data alone, using the
  session title as the card title.

  ## Variants

    * `:triage` - idle ticket in the triage column (drag-and-drop, triage actions)
    * `:triage_session` - non-ticket session in triage (completed/cancelled/awaiting_feedback)
    * `:queued` - queued item in build queue overflow zone
    * `:warm` - queued item in build queue warm zone (may be warming)
    * `:in_progress` - actively running item in build queue
    * `:failed` - failed item in build queue
    * `:optimistic` - optimistic queued item (syncing with server)

  ## Assigns

    * `:ticket` - the enriched ticket map, or nil for session-only cards (default nil)
    * `:variant` - one of the variant atoms above (required)
    * `:session` - the associated session map, or nil (default nil)
    * `:active` - whether this card is currently selected (default false)
    * `:warming` - whether the item is currently warming (default false)
    * `:container_stats` - container stats map for this session, or nil (default nil)
    * `:depth` - hierarchy depth (0=root, 1=subticket)
    * `:auth_refreshing` - map of task_ids currently refreshing auth (default %{})
  """
  attr(:ticket, :map, default: nil)

  attr(:variant, :atom,
    required: true,
    values: [:triage, :triage_session, :queued, :warm, :in_progress, :failed, :optimistic]
  )

  attr(:session, :map, default: nil)
  attr(:active, :boolean, default: false)
  attr(:warming, :boolean, default: false)
  attr(:container_stats, :map, default: nil)
  attr(:depth, :integer, default: 0)
  attr(:auth_refreshing, :map, default: %{})

  def ticket_card(assigns) do
    session = normalize_session(assigns[:session])

    assigns =
      assigns
      |> assign(:session, session)
      |> assign(:has_container, has_real_container?(session))
      |> assign(:file_stats, compute_file_stats(session))
      |> assign(:closed, ticket_closed?(assigns[:ticket]))
      |> assign(:is_ticket, not is_nil(assigns[:ticket]))
      |> assign(:card_title, card_title(assigns[:ticket], session))
      |> assign(:card_status, card_status(assigns[:ticket], session))

    ~H"""
    <div
      data-testid={card_test_id(@variant, @ticket, @session)}
      data-triage-ticket-card={@variant == :triage || nil}
      data-ticket-number={(@variant == :triage && @is_ticket && @ticket.number) || nil}
      data-ticket-depth={@depth}
      data-has-subissues={(@is_ticket && to_string(Ticket.has_sub_tickets?(@ticket))) || "false"}
      data-ticket-state={(@is_ticket && @ticket.state) || nil}
      data-blocked={(@is_ticket && blocked_data_attr(@ticket)) || nil}
      data-slot-state={slot_state(@variant, @warming)}
      class={
        ticket_card_classes(
          @variant,
          @ticket,
          @session,
          @active,
          @warming,
          @has_container,
          @depth,
          @card_status
        )
      }
    >
      <%!-- Main row: content area + action strip --%>
      <div class="flex flex-1 min-w-0 min-h-0">
        <%!-- Card content area (clickable to select) --%>
        <div
          class="flex-1 min-w-0 flex flex-col items-start gap-1 p-2"
          phx-click={card_click_event(@is_ticket)}
          phx-value-number={(@is_ticket && @ticket.number) || nil}
          phx-value-container-id={(!@is_ticket && @session && @session.container_id) || nil}
        >
          <%!-- Header row: badges + status dot --%>
          <div class="flex items-start justify-between w-full gap-2">
            <div class="flex items-center gap-1.5 flex-wrap min-w-0">
              <%!-- Ticket number badge (ticket-backed cards only) --%>
              <span :if={@is_ticket} class="badge badge-xs badge-info whitespace-nowrap shrink-0">
                {@ticket.number}
              </span>
              <%!-- Closed badge --%>
              <span
                :if={@closed}
                class="badge badge-xs badge-ghost whitespace-nowrap shrink-0"
              >
                Closed
              </span>
              <%!-- Paused badge (triage ticket only) --%>
              <span
                :if={
                  !@closed && @variant == :triage && @is_ticket && @ticket.task_status == "cancelled"
                }
                class="badge badge-xs badge-ghost whitespace-nowrap shrink-0"
              >
                Paused
              </span>
              <%!-- Completed bell alert (triage session only) --%>
              <span
                :if={@variant == :triage_session && @session && @session.latest_status == "completed"}
                class="inline-flex items-center"
                title="Session completed — review output"
              >
                <.icon name="hero-bell-alert" class="size-3.5 text-warning" />
              </span>
              <span
                :if={@is_ticket && Ticket.has_sub_tickets?(@ticket)}
                class="badge badge-xs badge-outline whitespace-nowrap shrink-0"
              >
                {TicketHierarchyPolicy.sub_ticket_summary_text(@ticket)}
              </span>
              <span
                :if={@is_ticket && @ticket.lifecycle_stage}
                data-testid="ticket-lifecycle-stage"
                class={[
                  "badge badge-xs whitespace-nowrap shrink-0",
                  lifecycle_stage_badge_class(@ticket.lifecycle_stage)
                ]}
              >
                {View.lifecycle_stage_label(@ticket)}
              </span>
              <span
                :if={@is_ticket}
                data-testid="ticket-lifecycle-duration"
                class="text-[0.6rem] text-base-content/40 whitespace-nowrap shrink-0"
              >
                {View.current_stage_duration(@ticket, DateTime.utc_now())}
              </span>
              <%!-- Blocked indicator --%>
              <span
                :if={@is_ticket && Ticket.blocked_status(@ticket) == :active}
                data-testid="blocked-indicator"
                class="badge badge-xs badge-error whitespace-nowrap shrink-0"
              >
                Blocked by {Ticket.open_blocker_count(@ticket)}
              </span>
              <span
                :if={@is_ticket && Ticket.blocked_status(@ticket) == :resolved}
                data-testid="blocked-indicator"
                class="badge badge-xs badge-ghost whitespace-nowrap shrink-0"
              >
                Blockers resolved
              </span>
              <%!-- Auth refresh button (failed session-only cards) --%>
              <button
                :if={
                  @variant == :failed && !@is_ticket && @session && auth_error?(@session.latest_error) &&
                    @session.latest_task_id
                }
                type="button"
                phx-click="refresh_auth_and_resume"
                phx-value-task-id={@session.latest_task_id}
                disabled={auth_refreshing?(@auth_refreshing, @session.latest_task_id)}
                class="btn btn-ghost btn-xs p-0 min-h-0 h-auto"
                title="Refresh auth & resume"
              >
                <.icon
                  name="hero-arrow-path"
                  class={
                    if(auth_refreshing?(@auth_refreshing, @session.latest_task_id),
                      do: "size-3.5 text-warning animate-spin",
                      else: "size-3.5 text-warning"
                    )
                  }
                />
              </button>
              <%!-- Warming indicator (warm variant only) --%>
              <span
                :if={@variant == :warm && @warming}
                class="inline-flex items-center gap-1 text-[0.6rem] text-warning"
              >
                <.icon name="hero-arrow-path" class="size-3 animate-spin" /> Warming...
              </span>
              <%!-- Syncing badge (optimistic variant only) --%>
              <span
                :if={@variant == :optimistic}
                class="badge badge-xs badge-info badge-outline"
              >
                Syncing...
              </span>
            </div>
            <.status_dot
              status={@card_status}
              cold={ticket_card_cold?(@variant, @session, @warming, @has_container)}
            />
          </div>

          <%!-- Title (unified: always below the header row) --%>
          <span
            class={[
              "text-xs font-medium flex-1 min-w-0 overflow-hidden mt-0.5 mb-0.5",
              @closed && "line-through text-base-content/50"
            ]}
            style="display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;"
          >
            {@card_title}
          </span>

          <%!-- Labels (ticket-backed cards only) --%>
          <div
            :if={@is_ticket && @ticket.labels != []}
            class="flex w-full items-start justify-start gap-1.5 flex-wrap"
          >
            <span
              :for={label <- @ticket.labels || []}
              class={["badge badge-xs whitespace-nowrap", ticket_label_class(label)]}
            >
              {label}
            </span>
          </div>

          <%!-- Session metadata (unified: same layout for all variants) --%>
          <div
            :if={@session}
            class="flex items-center gap-2 text-[0.6rem] text-base-content/40 w-full"
          >
            <%!-- Triage ticket cards show a mini status dot for the associated session --%>
            <.status_dot :if={@variant == :triage} status={@session.latest_status} />
            <span :if={@session[:image]}>{image_label(@session.image)}</span>
            <span
              :if={@is_ticket && @ticket.associated_container_id}
              class="font-mono"
              title={@ticket.associated_container_id}
            >
              {short_container_id(@ticket.associated_container_id)}
            </span>
            <span :if={@session[:latest_at]}>{relative_time(@session.latest_at)}</span>
            <span :if={@file_stats} data-testid="session-file-stats">{@file_stats}</span>
            <span
              :if={Map.get(@session, :started_at) != nil}
              data-testid="session-duration"
            >
              &middot;
              <span
                id={duration_timer_id(@variant, @ticket, @session)}
                phx-hook="DurationTimer"
                data-started-at={
                  Map.get(@session, :started_at) &&
                    DateTime.to_iso8601(@session.started_at)
                }
                data-completed-at={
                  Map.get(@session, :completed_at) &&
                    DateTime.to_iso8601(@session.completed_at)
                }
              />
            </span>
          </div>

          <.container_stats_bars
            :if={@container_stats}
            stats={@container_stats}
          />
        </div>

        <%!-- Action strip: triage ticket actions (up/play/down) --%>
        <div
          :if={@variant == :triage && @is_ticket && !@closed}
          class="flex flex-col shrink-0 border-l border-info/20"
          style="width: 10%;"
        >
          <button
            type="button"
            phx-click="send_ticket_to_top"
            phx-value-number={@ticket.number}
            data-testid={"send-ticket-to-top-#{@ticket.number}"}
            class="flex-1 flex items-center justify-center text-base-content/30 hover:text-base-content/70 hover:bg-base-content/5 transition-colors cursor-pointer"
            title="Send to top"
          >
            <.icon name="hero-chevron-double-up-mini" class="size-3" />
          </button>
          <button
            type="button"
            phx-click="start_ticket_session"
            phx-value-number={@ticket.number}
            data-testid={"start-ticket-session-#{@ticket.number}"}
            class="flex-1 flex items-center justify-center text-success/50 hover:text-success hover:bg-success/10 transition-colors cursor-pointer"
            title="Start session for this ticket"
          >
            <.icon name="hero-play-solid" class="size-3" />
          </button>
          <button
            type="button"
            phx-click="send_ticket_to_bottom"
            phx-value-number={@ticket.number}
            data-testid={"send-ticket-to-bottom-#{@ticket.number}"}
            class="flex-1 flex items-center justify-center text-base-content/30 hover:text-base-content/70 hover:bg-base-content/5 transition-colors cursor-pointer"
            title="Send to bottom"
          >
            <.icon name="hero-chevron-double-down-mini" class="size-3" />
          </button>
        </div>
        <%!-- Action strip: build queue ticket pause button --%>
        <div
          :if={@variant not in [:triage, :triage_session, :failed] && @is_ticket && !@closed}
          class={[
            "flex flex-col shrink-0 border-l",
            @variant == :in_progress && "border-success/20",
            @variant != :in_progress && "border-base-content/10"
          ]}
          style="width: 10%;"
        >
          <button
            type="button"
            phx-click="remove_ticket_from_queue"
            phx-value-number={@ticket.number}
            data-testid={"pause-ticket-#{@ticket.number}"}
            class="flex-1 flex items-center justify-center text-base-content/30 hover:text-warning hover:bg-warning/10 transition-colors cursor-pointer"
            title="Pause and move to triage"
          >
            <.icon name="hero-pause-solid" class="size-3" />
          </button>
        </div>
        <%!-- Action strip: build queue session pause button --%>
        <div
          :if={
            @variant in [:in_progress, :queued, :warm] && !@is_ticket && @session &&
              @session.latest_task_id
          }
          class={[
            "flex flex-col shrink-0 border-l",
            @variant == :in_progress && "border-success/20",
            @variant != :in_progress && "border-base-content/10"
          ]}
          style="width: 10%;"
        >
          <button
            type="button"
            phx-click="pause_session"
            phx-value-task-id={@session.latest_task_id}
            data-testid={"pause-session-#{slugify(@session.title)}"}
            class="flex-1 flex items-center justify-center text-base-content/30 hover:text-warning hover:bg-warning/10 transition-colors cursor-pointer"
            title="Pause session"
          >
            <.icon name="hero-pause-solid" class="size-3" />
          </button>
        </div>
      </div>
      <%!-- Progress bar: full width at the bottom of the card --%>
      <.compact_progress_bar
        :if={@session}
        todo_items={session_todo_items(@session)}
      />
    </div>
    """
  end

  # ---- Card Helpers ----

  # Normalize session fields: optimistic entries use :instruction/:queued_at
  # instead of :title/:latest_at and may lack keys like :container_id.
  # Fills defaults so the template can use dot access uniformly.
  defp normalize_session(nil), do: nil

  defp normalize_session(session) do
    defaults = %{
      latest_at: nil,
      title: nil,
      container_id: nil,
      latest_status: nil,
      latest_error: nil,
      latest_task_id: nil,
      started_at: nil,
      completed_at: nil,
      todo_items: nil,
      session_summary: nil,
      image: nil
    }

    session = Map.merge(defaults, session)

    session
    |> then(fn s -> if s.latest_at, do: s, else: Map.put(s, :latest_at, s[:queued_at]) end)
    |> then(fn s -> if s.title, do: s, else: Map.put(s, :title, s[:instruction]) end)
  end

  # Test ID generation: ticket-backed cards use ticket number, session-only use slugified title
  defp card_test_id(:triage, %{number: n}, _session), do: "triage-ticket-item-#{n}"

  defp card_test_id(:optimistic, _ticket, %{title: title}),
    do: "optimistic-session-item-#{slugify(title)}"

  defp card_test_id(:optimistic, _ticket, _session), do: "optimistic-session-item-unknown"
  defp card_test_id(_variant, %{number: n}, _session), do: "build-ticket-item-#{n}"
  defp card_test_id(_variant, nil, %{title: title}), do: "session-item-#{slugify(title)}"
  defp card_test_id(_variant, nil, _session), do: "session-item-unknown"

  # Click event: ticket cards select by number, session cards by container_id
  defp card_click_event(true = _is_ticket), do: "select_ticket"
  defp card_click_event(false), do: "select_session"

  # Card title: prefer ticket title, fall back to session title/instruction (truncated)
  defp card_title(%{title: title}, _session), do: title
  defp card_title(nil, %{title: title}) when is_binary(title), do: truncate_instruction(title, 35)

  defp card_title(nil, %{instruction: instr}) when is_binary(instr),
    do: truncate_instruction(instr, 35)

  defp card_title(nil, nil), do: ""

  # Truncate a container ID (SHA256 hash) to a short prefix for display.
  # The full ID is available as a title attribute for hover/copy.
  defp short_container_id(id) when is_binary(id), do: String.slice(id, 0, 12)
  defp short_container_id(_), do: nil

  # Card status: prefer ticket task_status, fall back to session latest_status or status
  defp card_status(%{task_status: status}, _session), do: status || "idle"
  defp card_status(nil, %{latest_status: status}) when is_binary(status), do: status
  defp card_status(nil, %{status: status}) when is_binary(status), do: status
  defp card_status(nil, nil), do: "idle"

  defp ticket_closed?(%{state: "closed"}), do: true
  defp ticket_closed?(_), do: false

  defp blocked_data_attr(ticket) do
    case Ticket.blocked_status(ticket) do
      :active -> "active"
      :resolved -> "resolved"
      :none -> nil
    end
  end

  # Duration timer DOM id must be unique per card
  defp duration_timer_id(variant, %{number: n}, _session),
    do: "duration-#{variant}-ticket-#{n}"

  defp duration_timer_id(variant, nil, %{container_id: cid}),
    do: "duration-#{variant}-#{cid}"

  defp duration_timer_id(variant, _, _), do: "duration-#{variant}-unknown"

  defp slot_state(:triage, _), do: nil
  defp slot_state(:triage_session, _), do: "idle"
  defp slot_state(:queued, _), do: "queued"
  defp slot_state(:warm, true), do: "warming"
  defp slot_state(:warm, _), do: "warm"
  defp slot_state(:in_progress, _), do: "used"
  defp slot_state(:failed, _), do: "failed"
  defp slot_state(:optimistic, _), do: "optimistic-queued"

  defp ticket_card_classes(
         variant,
         ticket,
         session,
         active,
         warming,
         has_container,
         depth,
         card_status
       ) do
    closed = ticket_closed?(ticket)

    base =
      "flex flex-col cursor-pointer w-full rounded-lg min-h-12 border transition-all duration-150 hover:-translate-y-px hover:shadow-md hover:ring-1 hover:ring-base-content/20 overflow-hidden"

    depth_classes =
      if depth > 0,
        do: "subticket-card ml-4 border-base-content/20 text-[0.95em]",
        else: ""

    variant_classes =
      if closed,
        do: "border-base-content/10 bg-base-content/3 opacity-60",
        else: variant_classes(variant, ticket, session, warming, has_container, card_status)

    active_class =
      if active, do: "ring-2 ring-primary/60 shadow-sm shadow-primary/10", else: ""

    "#{base} #{variant_classes} #{active_class} #{depth_classes}"
  end

  # Unified status-driven color function — single source of truth for card colors.
  # Every card gets its border/bg from semantic status, not from which column it's in.
  defp status_color_classes("completed"), do: "border-violet-400/40 bg-violet-500/10"
  defp status_color_classes("failed"), do: "border-error/40 bg-error/10"
  defp status_color_classes("cancelled"), do: "border-base-content/20 bg-base-content/5"
  defp status_color_classes("awaiting_feedback"), do: "border-warning/40 bg-warning/10"
  defp status_color_classes("pending"), do: "border-success/40 bg-success/10"
  defp status_color_classes("starting"), do: "border-success/40 bg-success/10"
  defp status_color_classes("running"), do: "border-success/40 bg-success/10"
  defp status_color_classes("optimistic"), do: "border-info/35 bg-info/10"
  defp status_color_classes(_), do: "border-info/25 bg-info/5"

  defp variant_classes(:triage, _ticket, _session, _warming, _has_container, card_status) do
    "cursor-grab active:cursor-grabbing #{status_color_classes(card_status)}"
  end

  defp variant_classes(:triage_session, _ticket, _session, _warming, _has_container, card_status) do
    status_color_classes(card_status)
  end

  defp variant_classes(:failed, _ticket, _session, _warming, _has_container, _card_status) do
    status_color_classes("failed")
  end

  defp variant_classes(:queued, _ticket, _session, _warming, has_container, _card_status) do
    if has_container,
      do: "border-warning/40 bg-warning/10",
      else: "border-base-content/20 bg-base-content/8"
  end

  defp variant_classes(:warm, _ticket, _session, warming, has_container, _card_status) do
    cond do
      warming -> "border-warning/55 bg-warning/15 animate-pulse"
      has_container -> "border-warning/40 bg-warning/10"
      true -> "border-base-content/20 bg-base-content/8"
    end
  end

  defp variant_classes(:in_progress, _ticket, _session, _warming, _has_container, _card_status) do
    status_color_classes("running")
  end

  defp variant_classes(:optimistic, _ticket, _session, _warming, _has_container, _card_status) do
    status_color_classes("optimistic")
  end

  defp lifecycle_stage_badge_class("open"), do: "badge-ghost"
  defp lifecycle_stage_badge_class("ready"), do: "badge-info"
  defp lifecycle_stage_badge_class("in_progress"), do: "badge-warning"
  defp lifecycle_stage_badge_class("in_review"), do: "badge-primary"
  defp lifecycle_stage_badge_class("ci_testing"), do: "badge-accent"
  defp lifecycle_stage_badge_class("deployed"), do: "badge-success"
  defp lifecycle_stage_badge_class("closed"), do: "badge-neutral"
  defp lifecycle_stage_badge_class(_), do: "badge-outline"

  defp ticket_card_cold?(:triage, _session, _warming, _has_container), do: false
  defp ticket_card_cold?(:triage_session, _session, _warming, _has_container), do: false
  defp ticket_card_cold?(:failed, _session, _warming, _has_container), do: false
  defp ticket_card_cold?(:optimistic, _session, _warming, _has_container), do: false
  defp ticket_card_cold?(:warm, _session, warming, has_container), do: !warming and !has_container

  defp ticket_card_cold?(_variant, session, _warming, has_container),
    do: is_nil(session) or !has_container

  defp has_real_container?(nil), do: false

  defp has_real_container?(session) do
    container_id = Map.get(session, :container_id)

    is_binary(container_id) and container_id != "" and
      not String.starts_with?(container_id, "task:")
  end

  defp compute_file_stats(nil), do: nil
  defp compute_file_stats(session), do: format_file_stats(Map.get(session, :session_summary))

  # ---- Status Components (used by ticket_card) ----

  @doc "Renders a status badge with appropriate color."
  attr(:status, :string, required: true)

  def status_badge(%{status: "idle"} = assigns) do
    ~H"""
    <span class="badge badge-sm badge-ghost">idle</span>
    """
  end

  def status_badge(assigns) do
    ~H"""
    <span class={[
      "badge badge-sm",
      @status == "pending" && "badge-warning",
      @status == "starting" && "badge-warning",
      @status == "running" && "badge-info animate-pulse",
      @status == "completed" && "badge-success",
      @status == "failed" && "badge-error",
      @status == "cancelled" && "badge-ghost",
      @status == "queued" && "badge-neutral",
      @status == "awaiting_feedback" && "badge-warning animate-pulse"
    ]}>
      {format_badge_label(@status)}
    </span>
    """
  end

  defp format_badge_label("awaiting_feedback"), do: "awaiting feedback"
  defp format_badge_label(status), do: status

  @doc "Renders a small colored dot for session/task status."
  attr(:status, :string, required: true)
  attr(:cold, :boolean, default: false)

  def status_dot(assigns) do
    ~H"""
    <span class={[
      "inline-block size-2 rounded-full shrink-0",
      @cold && "bg-base-content/35",
      @status == "pending" && "bg-warning",
      @status == "starting" && "bg-warning",
      @status == "running" && "bg-info animate-pulse",
      @status == "completed" && "bg-success",
      @status == "failed" && "bg-error",
      @status == "cancelled" && "bg-base-content/30",
      @status == "queued" && !@cold && "bg-neutral",
      @status == "awaiting_feedback" && "bg-warning animate-pulse"
    ]}>
    </span>
    """
  end

  # ---- Container Stats ----

  @doc "Renders CPU and memory usage bars for a container."
  attr(:stats, :map, required: true)

  def container_stats_bars(assigns) do
    ~H"""
    <div class="flex flex-col gap-0.5 w-full mt-1">
      <div class="flex items-center gap-1.5">
        <span class="text-[0.6rem] text-base-content/40 w-7 shrink-0">CPU</span>
        <div class="flex-1 bg-base-300 rounded-full h-1.5 overflow-hidden">
          <div
            class="bg-info h-full rounded-full transition-all duration-500"
            style={"width: #{min(@stats.cpu_percent, 100)}%"}
          >
          </div>
        </div>
        <span class="text-[0.6rem] text-base-content/40 w-8 text-right shrink-0">
          {Float.round(@stats.cpu_percent, 0) |> trunc()}%
        </span>
      </div>
      <div class="flex items-center gap-1.5">
        <span class="text-[0.6rem] text-base-content/40 w-7 shrink-0">MEM</span>
        <div class="flex-1 bg-base-300 rounded-full h-1.5 overflow-hidden">
          <div
            class={[
              "h-full rounded-full transition-all duration-500",
              if(@stats.memory_percent >= 90, do: "bg-error", else: "bg-success")
            ]}
            style={"width: #{min(@stats.memory_percent, 100)}%"}
          >
          </div>
        </div>
        <span class="text-[0.6rem] text-base-content/40 w-8 text-right shrink-0">
          {format_mem_short(@stats.memory_usage)}
        </span>
      </div>
    </div>
    """
  end

  # ---- Lifecycle Timeline ----

  attr(:ticket, :map, required: true)

  def lifecycle_timeline(assigns) do
    timeline = View.lifecycle_timeline_data(assigns.ticket)
    assigns = assign(assigns, :timeline, timeline)

    ~H"""
    <div :if={@timeline != []} data-testid="ticket-lifecycle-timeline" class="mt-4 space-y-2">
      <div
        :for={item <- @timeline}
        data-testid="ticket-lifecycle-timeline-stage"
        class="rounded border border-base-300 p-2"
      >
        <div class="flex items-center justify-between">
          <span class="text-xs font-medium">{item.label}</span>
          <span
            data-testid="ticket-lifecycle-timeline-stage-duration"
            class="text-xs text-base-content/60"
          >
            {item.duration}
          </span>
        </div>
        <div class="mt-1 h-1.5 rounded bg-base-300">
          <div
            data-testid="ticket-lifecycle-duration-bar"
            data-stage={item.stage}
            data-relative-width={round(item.relative_width)}
            class="h-1.5 rounded bg-primary"
            style={"width: #{item.relative_width}%"}
          >
          </div>
        </div>
      </div>
    </div>
    """
  end

  # ---- Label Picker ----

  @doc """
  Renders a label picker with toggleable label badges.

  Shows all available labels from the predefined set. Currently applied
  labels are highlighted. Clicking a label emits an "update_ticket_labels"
  event with the toggled label list.

  ## Assigns

    * `:ticket` - the ticket struct/map with `:number` and `:labels` fields (required)
  """
  attr(:ticket, :map, required: true)

  def label_picker(assigns) do
    assigns = assign(assigns, :labels, assigns.ticket.labels || [])

    ~H"""
    <div data-testid="label-picker" class="mt-4">
      <div class="text-xs font-semibold uppercase tracking-wider text-base-content/60 mb-2">
        Labels
      </div>
      <div class="flex flex-wrap gap-1.5">
        <button
          :for={label <- available_labels()}
          type="button"
          phx-click="update_ticket_labels"
          phx-value-number={@ticket.number}
          phx-value-labels={Jason.encode!(toggle_label(@labels, label))}
          data-testid={"label-toggle-#{label}"}
          class={[
            "badge badge-sm cursor-pointer transition-all hover:scale-105",
            ticket_label_class(label),
            if(label in @labels,
              do: "opacity-100 ring-1 ring-primary/40",
              else: "opacity-40 hover:opacity-70"
            )
          ]}
        >
          {label}
        </button>
      </div>
    </div>
    """
  end

  @doc false
  def toggle_label(current_labels, label) do
    if label in current_labels do
      List.delete(current_labels, label)
    else
      [label | current_labels] |> Enum.sort()
    end
  end
end
