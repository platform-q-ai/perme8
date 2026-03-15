defmodule AgentsWeb.DashboardLive.Components.ChatOutputComponents do
  @moduledoc """
  Chat and output display components for the dashboard LiveView.

  Contains components for rendering chat timeline parts (user messages,
  assistant output, subtask cards), output parts (text, reasoning, tool calls),
  progress bars, queued messages, and markdown/formatting helpers.
  """
  use Phoenix.Component

  import AgentsWeb.CoreComponents

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

  # ---- Progress Bar ----

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
      class="flex gap-0.5 w-full px-2 pb-1.5"
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

  # ---- Chat Part ----

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

  def chat_part(%{part: {:answer_submitted, _id, text}} = assigns) do
    assigns = assign(assigns, :text, text)

    ~H"""
    <div class="flex gap-2 mb-3">
      <div class="shrink-0 size-6 rounded-full bg-success/10 flex items-center justify-center">
        <.icon name="hero-check-circle" class="size-3.5 text-success" />
      </div>
      <div class="flex-1 min-w-0">
        <div class="text-xs font-medium text-success/70 mb-0.5">Answer submitted</div>
        <div class="text-sm whitespace-pre-line break-words">{@text}</div>
        <div class="text-[11px] text-base-content/40 mt-0.5">Awaiting response...</div>
      </div>
    </div>
    """
  end

  def chat_part(%{part: {:subtask, id, detail}} = assigns) do
    assigns =
      assigns
      |> assign(:subtask_id, id)
      |> assign(:agent, detail.agent)
      |> assign(:description, detail.description)
      |> assign(:prompt, detail.prompt)
      |> assign(:subtask_status, detail.status)

    ~H"""
    <div class="flex gap-2 mb-3">
      <div class="shrink-0 size-6 rounded-full bg-info/10 flex items-center justify-center mt-0.5">
        <.icon name="hero-arrow-path-rounded-square" class="size-3.5 text-info" />
      </div>
      <div class="flex-1 min-w-0">
        <details class="my-0.5 rounded-lg border border-info/20 bg-info/5 text-xs group">
          <summary class="flex items-center gap-2 px-3 py-1.5 cursor-pointer select-none">
            <span
              :if={@subtask_status == :running}
              class="loading loading-spinner loading-xs text-info"
            >
            </span>
            <.icon
              :if={@subtask_status == :done}
              name="hero-check-circle"
              class="size-3.5 text-success"
            />
            <span class="font-medium text-info/90">
              Subtask: {@agent}
            </span>
            <span :if={@description != ""} class="text-base-content/50 truncate flex-1">
              {@description}
            </span>
            <.icon
              name="hero-chevron-right"
              class="size-3 text-base-content/30 ml-auto transition-transform group-open:rotate-90 shrink-0"
            />
          </summary>
          <div class="px-3 py-2 border-t border-info/10">
            <div class="text-[0.6rem] font-semibold text-base-content/40 uppercase tracking-wider mb-0.5">
              Prompt
            </div>
            <div class="text-[0.7rem] leading-snug text-base-content/60 whitespace-pre-wrap break-words max-h-48 overflow-y-auto">
              {@prompt}
            </div>
          </div>
        </details>
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

  # ---- Output Part ----

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

  # ---- Progress Bar Helpers ----

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
end
