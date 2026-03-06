defmodule AgentsWeb.SessionsLive.Components.SessionComponents do
  @moduledoc """
  Reusable components for the Sessions LiveView.

  Contains display components for session status, output parts (text, reasoning,
  tool calls), container stats, question cards, and todo progress bar. Extracted
  from the main `AgentsWeb.SessionsLive.Index` to keep the LiveView module
  focused on event handling and state management.
  """
  use Phoenix.Component

  import AgentsWeb.CoreComponents

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
  Renders the AI assistant's question with selectable options.

  When rejected (dismissed/timed out), the card stays visible with muted styling.
  Submitting an answer to a rejected question sends it as a follow-up message.
  """
  attr(:pending, :map, required: true)

  def question_card(assigns) do
    assigns = assign(assigns, :rejected, assigns.pending.rejected || false)

    ~H"""
    <div class={[
      "mt-3 rounded-lg border-2 p-4",
      if(@rejected, do: "border-base-300 bg-base-200/50", else: "border-warning/40 bg-warning/5")
    ]}>
      <div class="flex items-center gap-2 mb-3">
        <.icon
          name={if(@rejected, do: "hero-arrow-path", else: "hero-question-mark-circle")}
          class={if(@rejected, do: "size-5 text-base-content/50", else: "size-5 text-warning")}
        />
        <span class={[
          "font-semibold text-sm",
          if(@rejected, do: "text-base-content/50", else: "text-warning")
        ]}>
          {if @rejected,
            do: "Question dismissed — you can still respond",
            else: "Question from Assistant"}
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
            <.icon name="hero-check" class="size-4" />
            {if @rejected, do: "Send as Message", else: "Submit Answer"}
          </button>
          <button
            type="button"
            phx-click="dismiss_question"
            class="btn btn-ghost btn-sm"
          >
            {if @rejected, do: "Close", else: "Dismiss"}
          </button>
        </div>
      </form>
    </div>
    """
  end

  # ---- Queued Message ----

  @doc """
  Renders a queued user message with muted styling and a "Queued" badge.

  Shown in the output log when the user sends a follow-up message while
  the agent is still processing. The message is visually dimmed to
  distinguish it from delivered messages.
  """
  attr(:message, :map, required: true)

  def queued_message(assigns) do
    status = Map.get(assigns.message, :status, "pending")
    badge = queued_message_badge(status)
    status_text = queued_message_status_text(status)

    assigns =
      assigns
      |> assign(:status, status)
      |> assign(:badge, badge)
      |> assign(:status_text, status_text)

    ~H"""
    <div
      data-testid={"queued-message-#{@message.id}"}
      class={[
        "flex gap-2 mb-3",
        @status in ["pending"] && "opacity-60",
        @status in ["rolled_back"] && "opacity-80"
      ]}
    >
      <div class="shrink-0 size-6 rounded-full bg-primary/10 flex items-center justify-center">
        <.icon name="hero-user" class="size-3.5 text-primary" />
      </div>
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2 mb-0.5">
          <span class="text-xs font-medium text-base-content/50">You</span>
          <span class={[@badge, "badge badge-xs text-[0.6rem]"]}>
            {queued_message_label(@status)}
          </span>
        </div>
        <div class="text-sm whitespace-pre-line break-words text-base-content/60">
          {String.trim(@message.content)}
        </div>
        <div :if={@status_text} class="text-[11px] text-base-content/40 mt-0.5">{@status_text}</div>
      </div>
    </div>
    """
  end

  defp queued_message_label("rolled_back"), do: "Failed"
  defp queued_message_label(_), do: "Queued"

  defp queued_message_badge("rolled_back"), do: "badge-error"
  defp queued_message_badge(_), do: "badge-ghost"

  defp queued_message_status_text("rolled_back"), do: "Rolled back before backend acceptance"
  defp queued_message_status_text("pending"), do: nil
  defp queued_message_status_text(_), do: nil

  # ---- Output Part Components ----

  @doc """
  Renders a horizontal todo progress bar for session task steps.

  Each step is a colored segment in a horizontal bar. Hovering a segment
  shows a tooltip with the step number, title, and status.
  """
  attr(:todo_items, :list, required: true)

  def progress_bar(assigns) do
    ~H"""
    <section
      :if={@todo_items != []}
      data-testid="todo-progress"
      class="mb-2"
    >
      <div
        data-testid="todo-progress-summary"
        class="mb-1.5 text-xs font-semibold uppercase tracking-wide text-base-content/60"
      >
        {completed_count(@todo_items)}/{length(@todo_items)} steps complete
      </div>

      <div class="flex gap-1 w-full">
        <%= for item <- @todo_items do %>
          <div
            data-testid={"todo-step-#{display_position(item)}"}
            class={[
              "is-#{status_class(item.status)} group relative flex-1 h-3 rounded-full transition-all duration-300 cursor-pointer",
              segment_bg(item.status)
            ]}
          >
            <%!-- Tooltip on hover --%>
            <div class="pointer-events-none absolute bottom-full left-1/2 -translate-x-1/2 mb-2 opacity-0 group-hover:opacity-100 transition-opacity duration-150 z-20">
              <div class={[
                "whitespace-nowrap rounded-lg border px-2.5 py-1.5 text-xs font-medium shadow-lg",
                tooltip_colors(item.status)
              ]}>
                <span class="font-semibold">{display_position(item)}.</span> {item.title}
                <span class={[
                  "ml-1.5 text-[0.6rem] uppercase tracking-wider",
                  tooltip_status_text(item.status)
                ]}>
                  {format_status(item.status)}
                </span>
              </div>
              <div class={[
                "absolute left-1/2 -translate-x-1/2 top-full w-0 h-0 border-x-4 border-x-transparent border-t-4",
                tooltip_arrow(item.status)
              ]}>
              </div>
            </div>
          </div>
        <% end %>
      </div>
    </section>
    """
  end

  @doc """
  Renders a compact horizontal progress bar for session list cards.

  Shows a thin bar with colored segments -- no text, no tooltips.
  """
  attr(:todo_items, :list, required: true)

  def compact_progress_bar(assigns) do
    ~H"""
    <div
      :if={@todo_items != []}
      data-testid="session-todo-progress"
      class="flex gap-0.5 w-full mt-1"
    >
      <%= for item <- @todo_items do %>
        <div class={[
          "flex-1 h-1.5 rounded-full transition-all duration-300",
          segment_bg(item.status)
        ]}>
        </div>
      <% end %>
    </div>
    """
  end

  @doc """
  Renders a single chat timeline part with role-specific chrome.

  User parts are shown as user bubbles, while assistant/tool/reasoning
  parts use assistant styling and delegate body rendering to output_part/1.
  """
  attr(:part, :any, required: true)

  def chat_part(%{part: {:user, _id, text}} = assigns) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <div class="flex gap-2 mb-3">
      <div class="shrink-0 size-6 rounded-full bg-primary/10 flex items-center justify-center">
        <.icon name="hero-user" class="size-3.5 text-primary" />
      </div>
      <div class="flex-1 min-w-0">
        <div class="text-xs font-medium text-base-content/50 mb-0.5">You</div>
        <div class="text-sm whitespace-pre-line break-words">{@text}</div>
      </div>
    </div>
    """
  end

  def chat_part(%{part: {:user_pending, _id, text}} = assigns) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <div class="flex gap-2 mb-3">
      <div class="shrink-0 size-6 rounded-full bg-primary/10 flex items-center justify-center">
        <.icon name="hero-user" class="size-3.5 text-primary" />
      </div>
      <div class="flex-1 min-w-0">
        <div class="text-xs font-medium text-base-content/50 mb-0.5">You</div>
        <div class="text-sm whitespace-pre-line break-words">{@text}</div>
        <div class="text-[11px] text-base-content/40 mt-0.5">Awaiting response...</div>
      </div>
    </div>
    """
  end

  def chat_part(assigns) do
    ~H"""
    <div class="flex gap-2 mb-3">
      <div class="shrink-0 size-6 rounded-full bg-secondary/10 flex items-center justify-center mt-0.5">
        <.icon name="hero-cpu-chip" class="size-3.5 text-secondary" />
      </div>
      <div class="flex-1 min-w-0">
        <div class="text-xs font-medium text-base-content/50 mb-0.5">Assistant</div>
        <.output_part part={@part} />
      </div>
    </div>
    """
  end

  @doc """
  Renders a single output part (text, reasoning, or tool call).

  Accepts a tuple as the `part` assign:
  - `{:text, id, text, :streaming | :frozen}`
  - `{:reasoning, id, text, :streaming | :frozen}`
  - `{:tool, id, name, status, detail_map}`
  - Legacy 3/4/5-tuple tool variants
  """
  attr(:part, :any, required: true)

  # Streaming text — render raw for speed (character-by-character feel)
  def output_part(%{part: {:text, _id, text, :streaming}} = assigns) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <div class="session-markdown py-1 whitespace-pre-wrap break-words">
      {@text}<span class="inline-block w-2 h-4 bg-primary/70 animate-pulse align-text-bottom ml-0.5"></span>
    </div>
    """
  end

  # Frozen text — render as markdown (final form)
  def output_part(%{part: {:text, _id, text, :frozen}} = assigns) do
    assigns = assign(assigns, :rendered_html, render_markdown(text))

    ~H"""
    <div class="session-markdown py-1">{@rendered_html}</div>
    """
  end

  # Streaming reasoning — render raw in a thinking block
  def output_part(%{part: {:reasoning, _id, text, :streaming}} = assigns) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <div class="my-1 rounded-lg border border-base-300 bg-base-200/30 text-xs">
      <div class="flex items-center gap-1.5 px-3 py-1.5 border-b border-base-300/50">
        <span class="loading loading-dots loading-xs text-secondary"></span>
        <span class="font-medium text-secondary/80 text-[0.65rem] uppercase tracking-wider">
          Thinking
        </span>
      </div>
      <div class="px-3 py-2 whitespace-pre-wrap break-words text-base-content/60 max-h-48 overflow-y-auto">
        {@text}
      </div>
    </div>
    """
  end

  # Frozen reasoning — render as markdown in a thinking block
  def output_part(%{part: {:reasoning, _id, text, :frozen}} = assigns) do
    assigns = assign(assigns, :rendered_html, render_markdown(text))

    ~H"""
    <details class="my-1 rounded-lg border border-base-300 bg-base-200/30 text-xs group">
      <summary class="flex items-center gap-1.5 px-3 py-1.5 cursor-pointer select-none">
        <.icon name="hero-light-bulb" class="size-3.5 text-secondary/70" />
        <span class="font-medium text-secondary/80 text-[0.65rem] uppercase tracking-wider">
          Thinking
        </span>
        <.icon
          name="hero-chevron-right"
          class="size-3 text-base-content/40 ml-auto transition-transform group-open:rotate-90"
        />
      </summary>
      <div class="px-3 py-2 border-t border-base-300/50 session-markdown text-base-content/60 max-h-64 overflow-y-auto">
        {@rendered_html}
      </div>
    </details>
    """
  end

  # Tool card — 5-tuple: {:tool, id, name, status, detail}
  # detail is a map with :title, :input, :output, :error keys
  def output_part(%{part: {:tool, id, name, status, detail}} = assigns)
      when is_map(detail) do
    title = detail[:title] || detail["title"]
    input = detail[:input] || detail["input"]
    output = detail[:output] || detail["output"]
    error = detail[:error] || detail["error"]

    assigns =
      assigns
      |> assign(:tool_id, id)
      |> assign(:name, name)
      |> assign(:tool_status, status)
      |> assign(:title, title)
      |> assign(:input, input)
      |> assign(:output, output)
      |> assign(:error, error)
      |> assign(:has_detail, !!(input || output || error))

    ~H"""
    <details
      id={"tool-detail-#{@tool_id}"}
      class="my-1 rounded-lg border border-base-300 bg-base-200/40 text-xs group"
    >
      <summary class="flex items-center gap-2 px-3 py-1.5 cursor-pointer select-none">
        <span :if={@tool_status == :running} class="loading loading-spinner loading-xs text-info">
        </span>
        <.icon :if={@tool_status == :done} name="hero-check-circle" class="size-3.5 text-success" />
        <.icon
          :if={@tool_status == :error}
          name="hero-exclamation-circle"
          class="size-3.5 text-error"
        />
        <span class="font-medium text-base-content/80">
          <.tool_icon name={@name} /> {@name}
        </span>
        <span :if={@title} class="text-base-content/50 truncate flex-1">{@title}</span>
        <.icon
          :if={@has_detail}
          name="hero-chevron-right"
          class="size-3 text-base-content/30 ml-auto transition-transform group-open:rotate-90 shrink-0"
        />
      </summary>
      <div :if={@has_detail} class="border-t border-base-300/50">
        <div :if={@input} class="px-3 py-1.5">
          <div class="text-[0.6rem] font-semibold text-base-content/40 uppercase tracking-wider mb-0.5">
            Input
          </div>
          <pre class="text-[0.65rem] leading-snug text-base-content/60 whitespace-pre-wrap break-all max-h-32 overflow-y-auto"><code>{format_tool_input(@input)}</code></pre>
        </div>
        <div :if={@output} class={["px-3 py-1.5", @input && "border-t border-base-300/30"]}>
          <div class="text-[0.6rem] font-semibold text-base-content/40 uppercase tracking-wider mb-0.5">
            Output
          </div>
          <pre class="text-[0.65rem] leading-snug text-base-content/60 whitespace-pre-wrap break-all max-h-32 overflow-y-auto"><code>{truncate_output(@output)}</code></pre>
        </div>
        <div
          :if={@error}
          class={["px-3 py-1.5", (@input || @output) && "border-t border-base-300/30"]}
        >
          <div class="text-[0.6rem] font-semibold text-error/70 uppercase tracking-wider mb-0.5">
            Error
          </div>
          <pre class="text-[0.65rem] leading-snug text-error/80 whitespace-pre-wrap break-all max-h-32 overflow-y-auto"><code>{@error}</code></pre>
        </div>
      </div>
    </details>
    """
  end

  # Tool with non-map detail (legacy plain input value)
  def output_part(%{part: {:tool, id, name, status, input}} = assigns)
      when not is_map(input) do
    detail = %{input: input, title: nil, output: nil, error: nil}
    assigns = Map.put(assigns, :part, {:tool, id, name, status, detail})
    output_part(assigns)
  end

  # Legacy 4-tuple tool compat {:tool, name, status, input}
  def output_part(%{part: {:tool, name, status, input}} = assigns)
      when is_atom(status) do
    detail =
      if is_map(input), do: input, else: %{input: input, title: nil, output: nil, error: nil}

    assigns = Map.put(assigns, :part, {:tool, nil, name, status, detail})
    output_part(assigns)
  end

  # Legacy 3-tuple tool compat {:tool, name, status}
  def output_part(%{part: {:tool, name, status}} = assigns)
      when is_atom(status) do
    assigns =
      Map.put(
        assigns,
        :part,
        {:tool, nil, name, status, %{input: nil, title: nil, output: nil, error: nil}}
      )

    output_part(assigns)
  end

  def output_part(assigns) do
    ~H"""
    """
  end

  # ---- Tool Icon ----

  defp tool_icon(%{name: name} = assigns) do
    assigns = assign(assigns, :icon_name, tool_icon_name(name))

    ~H"""
    <.icon name={@icon_name} class="size-3 inline-block" />
    """
  end

  defp tool_icon_name("bash"), do: "hero-command-line"
  defp tool_icon_name("read"), do: "hero-document-text"
  defp tool_icon_name("write"), do: "hero-pencil-square"
  defp tool_icon_name("edit"), do: "hero-pencil"
  defp tool_icon_name("glob"), do: "hero-folder-open"
  defp tool_icon_name("grep"), do: "hero-magnifying-glass"
  defp tool_icon_name("list"), do: "hero-list-bullet"
  defp tool_icon_name(_), do: "hero-wrench-screwdriver"

  defp completed_count(todo_items) do
    Enum.count(todo_items, &(&1.status == "completed"))
  end

  defp display_position(%{position: position}) when is_integer(position), do: position + 1
  defp display_position(_item), do: 1

  defp status_class(status) when is_binary(status), do: String.replace(status, "_", "-")
  defp status_class(status) when is_atom(status), do: status |> Atom.to_string() |> status_class()
  defp status_class(_), do: "pending"

  # Segment background colors for horizontal progress bar
  defp segment_bg("completed"), do: "bg-success"
  defp segment_bg("in_progress"), do: "bg-info animate-pulse"
  defp segment_bg("failed"), do: "bg-error"
  defp segment_bg(_), do: "bg-base-300"

  # Tooltip container colors
  defp tooltip_colors("completed"), do: "border-success/40 bg-success/10 text-success"
  defp tooltip_colors("in_progress"), do: "border-info/40 bg-info/10 text-info"
  defp tooltip_colors("failed"), do: "border-error/40 bg-error/10 text-error"
  defp tooltip_colors(_), do: "border-base-300 bg-base-200 text-base-content/80"

  # Tooltip status label text color
  defp tooltip_status_text("completed"), do: "text-success/70"
  defp tooltip_status_text("in_progress"), do: "text-info/70"
  defp tooltip_status_text("failed"), do: "text-error/70"
  defp tooltip_status_text(_), do: "text-base-content/50"

  # Tooltip arrow border-top color
  defp tooltip_arrow("completed"), do: "border-t-success/40"
  defp tooltip_arrow("in_progress"), do: "border-t-info/40"
  defp tooltip_arrow("failed"), do: "border-t-error/40"
  defp tooltip_arrow(_), do: "border-t-base-300"

  # Human-readable status label for tooltips
  defp format_status("in_progress"), do: "in progress"
  defp format_status(status) when is_binary(status), do: status
  defp format_status(_), do: "pending"

  # ---- Status Components ----

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

  # ---- Queue Panel ----

  @doc """
  Renders the build queue status panel with concurrency controls.
  """
  attr(:queue_state, :map, required: true)
  attr(:user_id, :string, required: true)

  def queue_panel(assigns) do
    ~H"""
    <div
      :if={@queue_state}
      data-testid="queue-panel"
      class="px-4 py-2 border-b border-base-300 bg-base-100 shrink-0"
    >
      <div class="flex items-center justify-end">
        <div class="flex items-center gap-1.5">
          <span class="text-xs text-base-content/50">Limit:</span>
          <form phx-change="update_concurrency_limit" class="inline">
            <select
              id={"concurrency-limit-select-#{@user_id}"}
              name="concurrency_limit"
              phx-hook="ConcurrencyLimit"
              data-user-id={@user_id}
              class="select select-bordered select-xs w-14"
              data-testid="concurrency-limit-select"
            >
              <%= for n <- 1..5 do %>
                <option value={n} selected={n == @queue_state.concurrency_limit}>{n}</option>
              <% end %>
            </select>
          </form>

          <span class="text-xs text-base-content/50 ml-2">Fresh warm:</span>
          <form phx-change="update_warm_cache_limit" class="inline">
            <select
              id={"warm-cache-limit-select-#{@user_id}"}
              name="warm_cache_limit"
              phx-hook="WarmCacheLimit"
              data-user-id={@user_id}
              class="select select-bordered select-xs w-14"
              data-testid="fresh-warm-target-select"
            >
              <%= for n <- 0..5 do %>
                <option value={n} selected={n == Map.get(@queue_state, :warm_cache_limit, 2)}>
                  {n}
                </option>
              <% end %>
            </select>
          </form>
        </div>
      </div>
    </div>
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

  # ---- Helpers ----

  @doc false
  def format_tool_input(nil), do: ""
  def format_tool_input(input) when is_binary(input), do: input
  def format_tool_input(input) when is_map(input), do: Jason.encode!(input, pretty: true)
  def format_tool_input(input), do: inspect(input)

  @doc false
  def truncate_output(nil), do: ""

  def truncate_output(text) when is_binary(text) and byte_size(text) > 2000 do
    String.slice(text, 0, 2000) <> "\n... (truncated)"
  end

  def truncate_output(text) when is_binary(text), do: text
  def truncate_output(other), do: inspect(other)

  @doc false
  def format_mem_short(bytes) when bytes >= 1_073_741_824 do
    "#{Float.round(bytes / 1_073_741_824, 1)}G"
  end

  def format_mem_short(bytes) when bytes >= 1_048_576 do
    "#{Float.round(bytes / 1_048_576, 0) |> trunc()}M"
  end

  def format_mem_short(bytes) when bytes >= 1024 do
    "#{Float.round(bytes / 1024, 0) |> trunc()}K"
  end

  def format_mem_short(_bytes), do: "0"

  @doc false
  def render_markdown(text) when is_binary(text) do
    opts = [
      extension: [
        strikethrough: true,
        table: true,
        tasklist: true,
        autolink: true
      ]
    ]

    case MDEx.to_html(text, opts) do
      {:ok, html} -> Phoenix.HTML.raw(html)
      {:error, _} -> text
    end
  end

  def render_markdown(text), do: text

  # ---- Ticket Card ----

  import AgentsWeb.SessionsLive.Helpers,
    only: [
      ticket_label_class: 1,
      format_file_stats: 1,
      session_todo_items: 1,
      image_label: 1,
      relative_time: 1
    ]

  @doc """
  Unified ticket card component used across triage and build queue columns.

  Renders a ticket card with conditional styling, metadata, and actions
  based on the `variant` attribute.

  ## Variants

    * `:triage` - idle ticket in the triage column (drag-and-drop, triage actions)
    * `:queued` - queued ticket in build queue overflow zone
    * `:warm` - queued ticket in build queue warm zone (may be warming)
    * `:in_progress` - actively running ticket in build queue

  ## Assigns

    * `:ticket` - the enriched ticket map (required)
    * `:variant` - one of `:triage`, `:queued`, `:warm`, `:in_progress` (required)
    * `:session` - the associated session map, or nil (default nil)
    * `:active` - whether this ticket is currently selected (default false)
    * `:warming` - whether the ticket is currently warming (default false)
    * `:container_stats` - container stats map for this session, or nil (default nil)
  """
  attr(:ticket, :map, required: true)
  attr(:variant, :atom, required: true, values: [:triage, :queued, :warm, :in_progress])
  attr(:session, :map, default: nil)
  attr(:active, :boolean, default: false)
  attr(:warming, :boolean, default: false)
  attr(:container_stats, :map, default: nil)

  def ticket_card(assigns) do
    assigns =
      assigns
      |> assign(:has_container, has_real_container?(assigns[:session]))
      |> assign(:file_stats, compute_file_stats(assigns[:session]))

    ~H"""
    <div
      data-testid={ticket_card_test_id(@variant, @ticket.number)}
      data-triage-ticket-card={@variant == :triage || nil}
      data-ticket-number={(@variant == :triage && @ticket.number) || nil}
      data-slot-state={slot_state(@variant, @warming)}
      class={ticket_card_classes(@variant, @ticket, @session, @active, @warming, @has_container)}
    >
      <%!-- Ticket content area (clickable to select) --%>
      <div
        class="flex-1 min-w-0 flex flex-col items-start gap-1 p-2"
        phx-click="select_ticket"
        phx-value-number={@ticket.number}
      >
        <%!-- Header row: number badge + inline metadata + status dot --%>
        <div class="flex items-start justify-between w-full gap-2">
          <div class={[
            @variant == :triage && "flex flex-col items-start gap-1 flex-1 min-w-0",
            @variant != :triage && "flex items-center gap-1.5 flex-wrap min-w-0"
          ]}>
            <div class={[
              @variant == :triage && "flex items-center gap-1.5",
              @variant != :triage && "contents"
            ]}>
              <span class="badge badge-xs badge-info whitespace-nowrap shrink-0">
                {@ticket.number}
              </span>
              <%!-- Paused badge (triage only) --%>
              <span
                :if={@variant == :triage && @ticket.task_status == "cancelled"}
                class="badge badge-xs badge-ghost whitespace-nowrap shrink-0"
              >
                Paused
              </span>
              <%!-- Warming indicator (warm variant only) --%>
              <span
                :if={@variant == :warm && @warming}
                class="inline-flex items-center gap-1 text-[0.6rem] text-warning"
              >
                <.icon name="hero-arrow-path" class="size-3 animate-spin" /> Warming...
              </span>
            </div>
            <%!-- Inline session metadata (build variants, when not warming) --%>
            <span
              :if={@variant != :triage && !@warming && @session}
              class="text-[0.6rem] text-base-content/40"
            >
              {image_label(@session.image)}
            </span>
            <span
              :if={@variant != :triage && !@warming && @session}
              class="text-[0.6rem] text-base-content/40"
            >
              &middot; {relative_time(@session.latest_at)}
            </span>
            <span
              :if={
                @variant != :triage && !@warming && @session && Map.get(@session, :started_at) != nil
              }
              class="text-[0.6rem] text-base-content/40"
              data-testid="session-duration"
            >
              &middot;
              <span
                id={"duration-#{@variant}-ticket-#{@ticket.number}"}
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
            <%!-- Title (triage renders below the badge row) --%>
            <span
              :if={@variant == :triage}
              class="text-xs font-medium flex-1 min-w-0 overflow-hidden mt-0.5 mb-0.5"
              style="display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;"
            >
              {@ticket.title}
            </span>
          </div>
          <.status_dot
            status={@ticket.task_status || "idle"}
            cold={ticket_card_cold?(@variant, @session, @warming, @has_container)}
          />
        </div>

        <%!-- Title (build variants render below the header row) --%>
        <span
          :if={@variant != :triage}
          class="text-xs font-medium flex-1 min-w-0 overflow-hidden mt-0.5 mb-0.5"
          style="display:-webkit-box;-webkit-line-clamp:2;-webkit-box-orient:vertical;"
        >
          {@ticket.title}
        </span>

        <%!-- Labels --%>
        <div
          :if={@ticket.labels != []}
          class="flex w-full items-start justify-start gap-1.5 flex-wrap"
        >
          <span
            :for={label <- @ticket.labels || []}
            class={["badge badge-xs whitespace-nowrap", ticket_label_class(label)]}
          >
            {label}
          </span>
        </div>

        <%!-- Session summary (triage: compact inline; build: full stats) --%>
        <div
          :if={@variant == :triage && @session}
          class="flex items-center gap-2 text-[0.6rem] text-base-content/40 w-full"
        >
          <.status_dot status={@session.latest_status} />
          <span>{relative_time(@session.latest_at)}</span>
          <span :if={@file_stats}>{@file_stats}</span>
        </div>

        <div
          :if={@variant != :triage && @file_stats}
          class="text-[0.6rem] text-base-content/40 w-full"
          data-testid="session-file-stats"
        >
          {@file_stats}
        </div>
        <.container_stats_bars
          :if={@variant != :triage && @container_stats}
          stats={@container_stats}
        />
        <.compact_progress_bar
          :if={@session}
          todo_items={session_todo_items(@session)}
        />
      </div>

      <%!-- Action strip (right edge) --%>
      <div
        :if={@variant == :triage}
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
      <div
        :if={@variant != :triage}
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
    </div>
    """
  end

  # ---- Ticket Card Helpers ----

  defp ticket_card_test_id(:triage, number), do: "triage-ticket-item-#{number}"
  defp ticket_card_test_id(_, number), do: "build-ticket-item-#{number}"

  defp slot_state(:triage, _), do: nil
  defp slot_state(:queued, _), do: "queued"
  defp slot_state(:warm, true), do: "warming"
  defp slot_state(:warm, _), do: "warm"
  defp slot_state(:in_progress, _), do: "used"

  defp ticket_card_classes(variant, ticket, session, active, warming, has_container) do
    base =
      "flex cursor-pointer w-full rounded-lg min-h-12 border transition-all duration-150 hover:-translate-y-px hover:shadow-md hover:ring-1 hover:ring-base-content/20 overflow-hidden"

    variant_classes =
      case variant do
        :triage ->
          grab = "cursor-grab active:cursor-grabbing"

          status_class =
            cond do
              ticket.task_status == "awaiting_feedback" -> "border-warning/40 bg-warning/10"
              ticket.task_status == "failed" -> "border-error/40 bg-error/10"
              ticket.task_status == "cancelled" -> "border-base-content/20 bg-base-content/5"
              true -> "border-info/25 bg-info/5"
            end

          "#{grab} #{status_class}"

        :queued ->
          cond do
            session && has_container -> "border-warning/40 bg-warning/10"
            true -> "border-base-content/20 bg-base-content/8"
          end

        :warm ->
          cond do
            warming -> "border-warning/55 bg-warning/15 animate-pulse"
            session && has_container -> "border-warning/40 bg-warning/10"
            true -> "border-base-content/20 bg-base-content/8"
          end

        :in_progress ->
          "border-success/40 bg-success/10"
      end

    active_class =
      if active, do: "ring-2 ring-primary/60 shadow-sm shadow-primary/10", else: ""

    "#{base} #{variant_classes} #{active_class}"
  end

  defp ticket_card_cold?(:triage, _session, _warming, _has_container), do: false
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
end
