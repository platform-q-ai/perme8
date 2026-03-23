defmodule AgentsWeb.DashboardLive.Components.DetailPanelComponents do
  @moduledoc """
  Function components for the dashboard right panel (session detail).

  Extracted from the main `index.html.heex` template to reduce its size.
  These are pure structural extractions — no behaviour changes.
  """
  use Phoenix.Component

  import AgentsWeb.CoreComponents
  import AgentsWeb.DashboardLive.Components.PRComponents
  import AgentsWeb.DashboardLive.Components.SessionComponents
  import AgentsWeb.DashboardLive.Helpers

  alias AgentsWeb.DashboardLive.EventProcessor
  alias AgentsWeb.DashboardLive.SessionStateMachine
  alias Agents.Tickets.Domain.Entities.Ticket
  alias Agents.Tickets.Domain.Policies.TicketHierarchyPolicy

  # -- Session Detail Header --

  @doc """
  Renders the session header bar: status badge, lifecycle state, title,
  docker image, delete/cancel buttons.
  """
  attr(:current_task, :map, default: nil)
  attr(:session_title, :string, default: nil)
  attr(:session_model, :string, default: nil)
  attr(:selected_ticket, :map, default: nil)
  attr(:active_container_id, :string, default: nil)
  attr(:sessions, :list, required: true)
  attr(:current_scope, :map, required: true)

  def session_detail_header(assigns) do
    ~H"""
    <div
      id="session-optimistic-state"
      phx-hook="SessionOptimisticState"
      data-user-id={@current_scope.user.id}
      data-task-id={if(@current_task, do: @current_task.id, else: nil)}
    >
    </div>

    <%!-- Session header --%>
    <div
      class="px-4 py-3 border-b border-base-300 flex items-center justify-between bg-base-100 shrink-0"
      data-testid="session-task-card"
      data-task-id={if(@current_task, do: @current_task.id, else: nil)}
    >
      <div class="flex items-center gap-2 min-w-0">
        <.status_badge status={if @current_task, do: @current_task.status, else: "idle"} />
        <span
          :if={@current_task}
          data-testid="lifecycle-state"
          class="badge badge-xs badge-outline whitespace-nowrap"
        >
          {SessionStateMachine.state_from_task(@current_task)
          |> SessionStateMachine.display_name()}
        </span>
        <span
          :if={
            @current_task &&
              SessionStateMachine.state_from_task(@current_task)
              |> SessionStateMachine.active?()
          }
          data-testid="state-predicate-active"
          class="hidden"
        >
        </span>
        <span
          :if={
            @current_task &&
              SessionStateMachine.state_from_task(@current_task)
              |> SessionStateMachine.terminal?()
          }
          data-testid="state-predicate-terminal"
          class="hidden"
        >
        </span>
        <h2 class="text-sm font-medium truncate">
          {@session_title ||
            if @current_task,
              do: truncate_instruction(@current_task.instruction, 60),
              else:
                (@selected_ticket && @selected_ticket.title) ||
                  "Session"}
        </h2>
      </div>
      <div class="flex items-center gap-2 shrink-0">
        <span
          :if={@current_task && @current_task.image}
          class="badge badge-sm badge-outline font-mono"
          title={"Docker image: #{@current_task.image}"}
        >
          <.icon name="hero-cube" class="size-3 mr-0.5" />
          {image_label(@current_task.image)}
        </span>
        <span
          :if={@session_model}
          class="text-xs text-base-content/50 font-mono"
        >
          {@session_model}
        </span>
        <button
          :if={@active_container_id && session_deletable?(@sessions, @active_container_id)}
          type="button"
          phx-click="delete_session"
          phx-value-container-id={@active_container_id}
          data-confirm="Delete this session and its container? This cannot be undone."
          class="btn btn-ghost btn-xs text-error"
          title="Delete session"
        >
          <.icon name="hero-trash" class="size-4" />
        </button>
        <button
          :if={@current_task && @current_task.status == "queued"}
          type="button"
          phx-click="delete_queued_task"
          phx-value-task-id={@current_task.id}
          phx-value-container-id={@active_container_id}
          data-confirm="Remove this queued session?"
          class="btn btn-ghost btn-xs text-error"
          title="Delete queued session"
        >
          <.icon name="hero-trash" class="size-4" />
        </button>
      </div>
    </div>
    """
  end

  # -- Chat Tab Panel --

  @doc """
  Renders the chat tab panel: stats bar, error/cancelled alerts, output log,
  queued messages, question card.
  """
  attr(:current_task, :map, default: nil)
  attr(:session_tokens, :map, default: nil)
  attr(:session_summary, :map, default: nil)
  attr(:output_parts, :list, required: true)
  attr(:queued_messages, :list, required: true)
  attr(:pending_question, :map, default: nil)
  attr(:auth_refreshing, :map, required: true)

  def chat_tab_panel(assigns) do
    ~H"""
    <div
      role="tabpanel"
      id="tabpanel-chat"
      aria-labelledby="tab-chat"
      class="flex-1 flex flex-col min-h-0 overflow-hidden"
      data-testid="chat-log"
    >
      <%!-- Stats bar --%>
      <div
        :if={@session_tokens || @session_summary}
        class="px-4 py-1.5 border-b border-base-300 flex flex-wrap gap-4 text-xs text-base-content/60 bg-base-100 shrink-0"
      >
        <div :if={@session_tokens} class="flex items-center gap-1">
          <.icon name="hero-arrow-down-tray" class="size-3" />
          <span>{format_token_count(@session_tokens["input"])} in</span>
        </div>
        <div :if={@session_tokens} class="flex items-center gap-1">
          <.icon name="hero-arrow-up-tray" class="size-3" />
          <span>{format_token_count(@session_tokens["output"])} out</span>
        </div>
        <div :if={@session_tokens && @session_tokens["cache"]} class="flex items-center gap-1">
          <.icon name="hero-circle-stack" class="size-3" />
          <span>{format_token_count(@session_tokens["cache"]["read"])} cached</span>
        </div>
        <div
          :if={@session_summary && @session_summary["files"] && @session_summary["files"] > 0}
          class="flex items-center gap-1"
        >
          <.icon name="hero-document-text" class="size-3" />
          <span>
            {Map.get(@session_summary, "files", 0)} files
            <span class="text-success">+{Map.get(@session_summary, "additions", 0)}</span>
            <span class="text-error">-{Map.get(@session_summary, "deletions", 0)}</span>
          </span>
        </div>
      </div>

      <div
        :if={
          @current_task && Map.get(@current_task, :setup_phase) &&
            Map.get(@current_task, :setup_instruction)
        }
        class="mx-4 mt-3 rounded-lg border border-info/20 bg-info/5 px-3 py-2"
        data-testid="task-setup-phase"
      >
        <div class="flex items-center gap-2 text-xs font-medium uppercase tracking-wide text-info">
          <.icon name="hero-wrench-screwdriver" class="size-4" />
          <span>
            Setup phase: {setup_phase_label(Map.get(@current_task, :setup_phase))}
          </span>
        </div>
        <p class="mt-1 text-sm text-base-content/80" data-testid="task-setup-instruction">
          {Map.get(@current_task, :setup_instruction)}
        </p>
      </div>

      <%!-- Error alert --%>
      <div
        :if={@current_task && @current_task.status == "failed" && @current_task.error}
        class="mx-4 mt-3 alert alert-error"
      >
        <.icon name="hero-exclamation-triangle" class="size-5 shrink-0" />
        <div class="flex-1">
          <h3 class="font-semibold">Task failed</h3>
          <p class="text-sm">{format_error(@current_task.error)}</p>
        </div>
        <div class="flex gap-1.5">
          <button
            :if={auth_error?(@current_task.error) && resumable_task?(@current_task)}
            type="button"
            phx-click="refresh_auth_and_resume"
            phx-value-task-id={@current_task.id}
            disabled={auth_refreshing?(@auth_refreshing, @current_task.id)}
            class="btn btn-sm btn-warning"
          >
            <.icon
              name="hero-arrow-path"
              class={
                if(auth_refreshing?(@auth_refreshing, @current_task.id),
                  do: "size-4 animate-spin",
                  else: "size-4"
                )
              }
            />
            {if auth_refreshing?(@auth_refreshing, @current_task.id),
              do: "Refreshing...",
              else: "Refresh Auth & Resume"}
          </button>
          <button
            :if={resumable_task?(@current_task)}
            type="button"
            phx-click="restart_session"
            class="btn btn-sm btn-ghost"
            data-testid="restart-session-btn"
          >
            <.icon name="hero-arrow-path" class="size-4" /> Restart
          </button>
        </div>
      </div>

      <%!-- Cancelled alert --%>
      <div
        :if={@current_task && @current_task.status == "cancelled"}
        class="mx-4 mt-3 alert alert-warning"
      >
        <.icon name="hero-no-symbol" class="size-5 shrink-0" />
        <div class="flex-1">
          <h3 class="font-semibold">Session cancelled</h3>
          <p class="text-sm">This session was cancelled and is no longer running.</p>
        </div>
        <button
          :if={resumable_task?(@current_task)}
          type="button"
          phx-click="restart_session"
          class="btn btn-sm btn-ghost"
          data-testid="restart-session-btn"
        >
          <.icon name="hero-arrow-path" class="size-4" /> Restart
        </button>
      </div>

      <%!-- Output log --%>
      <div
        class="flex-1 overflow-y-auto overflow-x-hidden p-4"
        id="session-log"
        phx-hook="SessionLog"
      >
        <%= if show_initial_instruction?(@current_task, @output_parts) do %>
          <%!-- User message --%>
          <div class="flex gap-2 mb-3" data-testid="session-initial-instruction">
            <div class="shrink-0 size-6 rounded-full bg-primary/10 flex items-center justify-center">
              <.icon name="hero-user" class="size-3.5 text-primary" />
            </div>
            <div class="flex-1 min-w-0">
              <div class="text-xs font-medium text-base-content/50 mb-0.5">You</div>
              <div class="text-sm whitespace-pre-line break-words">
                {String.trim(@current_task.instruction)}
              </div>
            </div>
          </div>
        <% end %>
        <%= if @output_parts == [] && task_running?(@current_task) do %>
          <div class="flex gap-2">
            <div class="shrink-0 size-6 rounded-full bg-secondary/10 flex items-center justify-center">
              <.icon name="hero-cpu-chip" class="size-3.5 text-secondary" />
            </div>
            <div class="flex items-center gap-2 text-base-content/50 text-sm">
              <span class="loading loading-dots loading-xs"></span>
              <span>Waiting for response...</span>
            </div>
          </div>
        <% end %>
        <%= if @output_parts == [] && !task_running?(@current_task) && @current_task == nil do %>
          <div class="flex flex-col items-center justify-center h-full text-base-content/40">
            <.icon name="hero-command-line" class="size-12 mb-3" />
            <p class="text-sm">Enter an instruction below to start</p>
          </div>
        <% end %>
        <%= for part <- @output_parts do %>
          <.chat_part part={part} />
        <% end %>
        <%!-- Queued user messages awaiting processing --%>
        <.queued_message :for={msg <- @queued_messages} message={msg} />

        <%!-- Show activity indicator when task is still running but all cached parts are frozen --%>
        <div
          :if={
            task_running?(@current_task) &&
              @output_parts != [] &&
              !EventProcessor.has_streaming_parts?(@output_parts)
          }
          class="flex items-center gap-2 text-base-content/40 text-xs py-1"
        >
          <span class="loading loading-dots loading-xs"></span>
          <span>Working...</span>
        </div>
        <%!-- Pending question from assistant --%>
        <.question_card
          :if={@pending_question}
          pending={@pending_question}
        />
      </div>
    </div>
    """
  end

  # -- Ticket Tab Panel --

  @doc """
  Renders the ticket detail panel: ticket header, parent breadcrumb,
  labels, body, sub-issues, dependencies, lifecycle timeline.
  """
  attr(:selected_ticket, :map, default: nil)
  attr(:parent_ticket, :map, default: nil)
  attr(:dependency_search_mode, :boolean, required: true)
  attr(:dependency_search_query, :string, required: true)
  attr(:dependency_search_results, :list, required: true)
  attr(:selected_dependency_target, :string, default: nil)
  attr(:dependency_direction, :string, default: nil)
  attr(:fixture, :string, default: nil)

  def ticket_tab_panel(assigns) do
    ~H"""
    <div
      role="tabpanel"
      id="tabpanel-ticket"
      aria-labelledby="tab-ticket"
      class="flex-1 min-h-0 overflow-y-auto p-4"
      data-testid="ticket-detail-panel"
    >
      <%= if @selected_ticket do %>
        <div
          class="max-w-3xl"
          data-testid="ticket-context-panel"
          data-ticket-type={if(Ticket.sub_ticket?(@selected_ticket), do: "subticket", else: "ticket")}
        >
          <div class="flex items-start justify-between gap-2 mb-2">
            <div class="text-lg font-semibold">{@selected_ticket.title}</div>
            <button
              type="button"
              phx-click="close_ticket"
              phx-value-number={@selected_ticket.number}
              data-confirm={"Close ticket ##{@selected_ticket.number}? This will close the issue on GitHub."}
              data-testid="close-ticket-btn"
              class="btn btn-xs btn-ghost text-error hover:bg-error/10 shrink-0"
              title="Close ticket"
            >
              <.icon name="hero-x-circle-mini" class="size-4" /> Close
            </button>
          </div>
          <div
            :if={@parent_ticket}
            class="text-xs text-base-content/60 mb-2"
            data-testid="ticket-detail-parent-breadcrumb"
          >
            Parent ticket:
            <button
              type="button"
              phx-click="select_ticket"
              phx-value-number={@parent_ticket.number}
              class="link link-hover ml-1"
            >
              #{@parent_ticket.number} {@parent_ticket.title}
            </button>
          </div>
          <div class="text-xs text-base-content/60 mb-3" data-testid="ticket-detail-labels">
            #{@selected_ticket.number}
            <span
              :for={label <- @selected_ticket.labels || []}
              class={["badge badge-xs whitespace-nowrap ml-1", ticket_label_class(label)]}
            >
              {label}
            </span>
          </div>
          <.label_picker ticket={@selected_ticket} />
          <div
            class="session-markdown text-sm text-base-content/90"
            data-testid="ticket-detail-body"
          >
            {render_markdown(@selected_ticket.body || "No ticket description provided.")}
          </div>
          <div
            :if={Ticket.has_sub_tickets?(@selected_ticket)}
            class="mt-4"
            data-testid="ticket-detail-subissues"
          >
            <div class="text-xs font-semibold uppercase tracking-wider text-base-content/60 mb-2">
              Sub-issues
              <span class="ml-1 text-base-content/50 normal-case">
                ({TicketHierarchyPolicy.sub_ticket_summary_text(@selected_ticket)})
              </span>
            </div>
            <div class="flex flex-col gap-1.5">
              <button
                :for={sub_ticket <- @selected_ticket.sub_tickets}
                type="button"
                phx-click="select_ticket"
                phx-value-number={sub_ticket.number}
                data-testid={"ticket-subissue-item-#{sub_ticket.number}"}
                class="text-left rounded border border-base-300 px-2 py-1 text-sm hover:bg-base-200"
              >
                #{sub_ticket.number} {sub_ticket.title}
              </button>
            </div>
          </div>
          <%!-- Dependency: Blocked By section --%>
          <div
            :if={length(@selected_ticket.blocked_by) > 0}
            data-testid="ticket-blocked-by-section"
            class="mt-4"
          >
            <div class="text-xs font-semibold uppercase tracking-wider text-base-content/60 mb-2">
              Blocked by
            </div>
            <div class="flex flex-col gap-1">
              <div
                :for={blocker <- @selected_ticket.blocked_by}
                class="flex items-center justify-between group"
              >
                <button
                  type="button"
                  phx-click="select_ticket"
                  phx-value-number={blocker.number}
                  class="text-sm text-primary hover:underline truncate"
                >
                  #{blocker.number} {blocker.title}
                </button>
                <button
                  type="button"
                  phx-click="remove_dependency"
                  phx-value-blocker-id={blocker.id}
                  phx-value-blocked-id={@selected_ticket.id}
                  data-testid="remove-dependency-button"
                  class="btn btn-ghost btn-xs opacity-0 group-hover:opacity-100"
                >
                  <.icon name="hero-x-mark" class="h-3 w-3" />
                </button>
              </div>
            </div>
          </div>

          <%!-- Dependency: Blocks section --%>
          <div
            :if={length(@selected_ticket.blocks) > 0}
            data-testid="ticket-blocks-section"
            class="mt-4"
          >
            <div class="text-xs font-semibold uppercase tracking-wider text-base-content/60 mb-2">
              Blocks
            </div>
            <div class="flex flex-col gap-1">
              <div
                :for={blocked <- @selected_ticket.blocks}
                class="flex items-center justify-between group"
              >
                <button
                  type="button"
                  phx-click="select_ticket"
                  phx-value-number={blocked.number}
                  class="text-sm text-primary hover:underline truncate"
                >
                  #{blocked.number} {blocked.title}
                </button>
                <button
                  type="button"
                  phx-click="remove_dependency"
                  phx-value-blocker-id={@selected_ticket.id}
                  phx-value-blocked-id={blocked.id}
                  data-testid="remove-dependency-button"
                  class="btn btn-ghost btn-xs opacity-0 group-hover:opacity-100"
                >
                  <.icon name="hero-x-mark" class="h-3 w-3" />
                </button>
              </div>
            </div>
          </div>

          <%!-- Session start prevention for blocked tickets --%>
          <div
            :if={Ticket.blocked?(@selected_ticket)}
            class="mt-3 p-2 bg-error/10 rounded-lg"
          >
            <p class="text-xs text-error font-semibold mb-1">
              Cannot start session — ticket is blocked by:
            </p>
            <div class="flex flex-col gap-0.5">
              <button
                :for={blocker <- Enum.filter(@selected_ticket.blocked_by, &(&1.state == "open"))}
                type="button"
                phx-click="select_ticket"
                phx-value-number={blocker.number}
                data-testid="blocker-ticket-link"
                class="text-xs text-primary hover:underline text-left"
              >
                #{blocker.number} {blocker.title}
              </button>
            </div>
          </div>

          <%!-- Add Dependency button --%>
          <button
            type="button"
            phx-click="add_dependency_start"
            data-testid="add-dependency-button"
            class="btn btn-ghost btn-xs mt-3 gap-1"
          >
            <.icon name="hero-link" class="h-3 w-3" /> Add dependency
          </button>

          <%!-- Dependency Search Overlay --%>
          <div
            :if={@dependency_search_mode}
            class="mt-2 p-3 bg-base-200 rounded-lg"
            data-testid="dependency-search-overlay"
          >
            <div class="flex items-center justify-between mb-2">
              <span class="text-xs font-semibold">Add Dependency</span>
              <button type="button" phx-click="cancel_dependency" class="btn btn-ghost btn-xs">
                <.icon name="hero-x-mark" class="h-3 w-3" />
              </button>
            </div>
            <input
              type="text"
              phx-keyup="dependency_search"
              phx-debounce="300"
              data-testid="dependency-search-input"
              placeholder="Search by ticket # or title..."
              class="input input-sm input-bordered w-full mb-2"
              value={@dependency_search_query}
            />
            <div
              :if={@dependency_search_results != []}
              data-testid="dependency-search-results"
              class="space-y-1 max-h-40 overflow-y-auto mb-2"
            >
              <button
                :for={result <- @dependency_search_results}
                type="button"
                phx-click="select_dependency_target"
                phx-value-ticket-id={result.id}
                data-testid="dependency-search-result"
                class={"btn btn-ghost btn-xs w-full justify-start #{if @selected_dependency_target == result.id, do: "btn-active", else: ""}"}
              >
                #{result.number} {result.title}
              </button>
            </div>
            <div :if={@selected_dependency_target} class="flex gap-1 mb-2">
              <button
                type="button"
                phx-click="set_dependency_direction"
                phx-value-direction="blocks"
                data-testid="dependency-direction-blocks"
                class={"btn btn-xs #{if @dependency_direction == "blocks", do: "btn-primary", else: "btn-ghost"}"}
              >
                This blocks that
              </button>
              <button
                type="button"
                phx-click="set_dependency_direction"
                phx-value-direction="blocked_by"
                data-testid="dependency-direction-blocked-by"
                class={"btn btn-xs #{if @dependency_direction == "blocked_by", do: "btn-primary", else: "btn-ghost"}"}
              >
                This is blocked by that
              </button>
            </div>
            <button
              :if={@selected_dependency_target && @dependency_direction}
              type="button"
              phx-click="confirm_dependency"
              data-testid="dependency-confirm-button"
              class="btn btn-primary btn-xs w-full"
            >
              Confirm
            </button>
          </div>

          <.lifecycle_timeline ticket={@selected_ticket} />

          <button
            :if={@fixture == "ticket_lifecycle_realtime_transition"}
            type="button"
            phx-click="simulate_ticket_transition_in_progress_to_in_review"
            data-testid="simulate-ticket-transition-in-progress-to-in-review"
            class="btn btn-xs btn-outline mt-3"
          >
            Simulate In Progress -> In Review
          </button>
          <div
            :if={Ticket.closed?(@selected_ticket) and Ticket.has_sub_tickets?(@selected_ticket)}
            class="mt-3 text-xs text-base-content/60"
          >
            {TicketHierarchyPolicy.sub_ticket_summary_text(@selected_ticket)}
          </div>
        </div>
      <% else %>
        <div
          class="flex flex-col items-center justify-center h-full text-base-content/40"
          data-testid="ticket-detail-panel"
        >
          <.icon name="hero-document-text" class="size-12 mb-3" />
          <p class="text-sm">Select a ticket to view details</p>
        </div>
      <% end %>
    </div>
    """
  end

  defp setup_phase_label(:on_create), do: "On create"
  defp setup_phase_label(:on_resume), do: "On resume"
  defp setup_phase_label(phase) when is_binary(phase), do: phase
  defp setup_phase_label(phase), do: phase |> to_string() |> String.replace("_", " ")

  # -- Session Input Form --

  @doc "Renders the PR tab panel for local internal review workflows."
  attr(:selected_pull_request, :map, default: nil)
  attr(:pr_diff_payload, :any, required: true)
  attr(:pr_review_threads, :list, required: true)
  attr(:pr_loading, :boolean, required: true)
  attr(:pr_error, :any, default: nil)
  attr(:show_inline_comment_form, :boolean, default: false)
  attr(:pr_review_decision, :string, default: "comment")

  def pr_tab_panel(assigns) do
    ~H"""
    <div
      role="tabpanel"
      id="tabpanel-pr"
      aria-labelledby="tab-pr"
      class="flex-1 min-h-0 overflow-y-auto p-4 space-y-4"
    >
      <%= if @selected_pull_request do %>
        <.pr_header selected_pull_request={@selected_pull_request} />
        <.pr_description selected_pull_request={@selected_pull_request} />

        <button
          type="button"
          class="btn btn-sm btn-outline"
          phx-click="pr_start_inline_comment"
          data-testid="pr-add-inline-comment-button"
        >
          Add inline comment
        </button>

        <form
          :if={@show_inline_comment_form}
          id="pr-inline-comment-form"
          phx-submit="pr_add_inline_comment"
        >
          <textarea
            name="comment[body]"
            class="textarea textarea-bordered textarea-sm w-full"
            data-testid="pr-inline-comment-input"
          ></textarea>
          <button type="submit" class="btn btn-sm mt-1">Add comment</button>
        </form>

        <%= if @pr_loading do %>
          <div class="text-sm text-base-content/60">Loading pull request...</div>
        <% else %>
          <.pr_diff pr_diff_payload={@pr_diff_payload} />
          <.pr_threads threads={@pr_review_threads} />
          <.pr_review_actions
            selected_pull_request={@selected_pull_request}
            pr_review_decision={@pr_review_decision}
          />
        <% end %>

        <div :if={@pr_error} class="text-xs text-warning">{inspect(@pr_error)}</div>
      <% else %>
        <div class="text-sm text-base-content/60">No pull request linked to this ticket.</div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders the bottom input area: image picker, instruction textarea,
  submit/cancel buttons.
  """
  attr(:current_task, :map, default: nil)
  attr(:composing_new, :boolean, required: true)
  attr(:available_images, :list, required: true)
  attr(:selected_image, :string, required: true)
  attr(:active_container_id, :string, default: nil)
  attr(:active_session_tab, :string, required: true)
  attr(:active_ticket_number, :integer, default: nil)
  attr(:todo_items, :list, default: [])
  attr(:form, :map, required: true)

  def session_input_form(assigns) do
    ~H"""
    <div class="border-t border-base-300 p-3 bg-base-100 shrink-0">
      <%!-- Image picker (only shown when composing a new session) --%>
      <div
        :if={@composing_new && !@current_task}
        class="flex items-center gap-2 mb-2"
      >
        <span class="text-xs text-base-content/60 shrink-0">Image:</span>
        <div class="flex gap-1.5">
          <button
            :for={img <- @available_images}
            type="button"
            phx-click="select_image"
            phx-value-image={img.name}
            class={[
              "btn btn-xs",
              if(@selected_image == img.name,
                do: "btn-primary",
                else: "btn-ghost btn-outline"
              )
            ]}
          >
            {img.label}
          </button>
        </div>
      </div>
      <form id="session-form" phx-submit="run_task" class="flex gap-2 items-end">
        <div class="flex-1">
          <.progress_bar todo_items={@todo_items} />

          <input
            :if={is_integer(@active_ticket_number)}
            type="hidden"
            name="ticket_number"
            value={@active_ticket_number}
          />

          <div id="session-instruction-wrap" phx-update="ignore">
            <textarea
              name="instruction"
              id="session-instruction"
              phx-hook="SessionForm"
              data-draft-key={
                cond do
                  is_integer(@active_ticket_number) ->
                    "ticket:#{@active_ticket_number}"

                  @active_container_id ->
                    "session:#{@active_container_id}"

                  @current_task ->
                    "task:#{@current_task.id}"

                  true ->
                    "session:new"
                end
              }
              rows="2"
              class="textarea textarea-bordered w-full text-sm leading-snug"
              placeholder={
                cond do
                  task_running?(@current_task) ->
                    "Send a message (queued until agent finishes)..."

                  resumable_task?(@current_task) ->
                    "Follow-up instruction..."

                  true ->
                    "Describe the coding task..."
                end
              }
            >{@form["instruction"].value}</textarea>
          </div>
        </div>
        <div class="flex gap-1 shrink-0">
          <.button
            :if={task_running?(@current_task)}
            type="button"
            variant="error"
            size="sm"
            phx-click="cancel_task"
            id="cancel-task-btn"
          >
            <.icon name="hero-stop" class="size-4" />
          </.button>
          <.button
            type="submit"
            variant={if(task_running?(@current_task), do: "ghost", else: "primary")}
            size="sm"
          >
            <%= cond do %>
              <% task_running?(@current_task) -> %>
                <.icon name="hero-chat-bubble-left-ellipsis" class="size-4" />
              <% resumable_task?(@current_task) -> %>
                <.icon name="hero-arrow-path" class="size-4" />
              <% true -> %>
                <.icon name="hero-paper-airplane" class="size-4" />
            <% end %>
          </.button>
        </div>
      </form>
    </div>
    """
  end
end
