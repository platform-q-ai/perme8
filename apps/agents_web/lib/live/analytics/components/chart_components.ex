defmodule AgentsWeb.AnalyticsLive.Components.ChartComponents do
  @moduledoc """
  Function components for rendering SVG charts and analytics UI elements.
  """

  use AgentsWeb, :html

  alias Agents.Tickets.Domain.Entities.AnalyticsView
  alias Agents.Tickets.Domain.Policies.TicketLifecyclePolicy

  @chart_width 700
  @chart_height 250
  @bar_chart_height 200

  @stage_css_colors %{
    "neutral" => "#6b7280",
    "info" => "#3b82f6",
    "warning" => "#f59e0b",
    "primary" => "#8b5cf6",
    "accent" => "#06b6d4",
    "success" => "#22c55e",
    "base" => "#9ca3af"
  }

  # Summary Cards

  attr(:summary, :map, required: true)

  def summary_cards(assigns) do
    display = AnalyticsView.summary_display(assigns.summary)
    assigns = assign(assigns, :display, display)

    ~H"""
    <div class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-6">
      <div class="stat bg-base-200 rounded-box p-4" data-testid="summary-card-total-tickets">
        <div class="stat-title text-xs">Total Tickets</div>
        <div class="stat-value text-2xl">{@display.total}</div>
      </div>
      <div class="stat bg-base-200 rounded-box p-4" data-testid="summary-card-open-tickets">
        <div class="stat-title text-xs">Open</div>
        <div class="stat-value text-2xl">{@display.open}</div>
      </div>
      <div class="stat bg-base-200 rounded-box p-4" data-testid="summary-card-avg-cycle-time">
        <div class="stat-title text-xs">Avg Cycle Time</div>
        <div class="stat-value text-2xl">{@display.avg_cycle_time}</div>
      </div>
      <div class="stat bg-base-200 rounded-box p-4" data-testid="summary-card-completed">
        <div class="stat-title text-xs">Completed</div>
        <div class="stat-value text-2xl">{@display.completed}</div>
      </div>
    </div>
    """
  end

  # Distribution Bar Chart

  attr(:distribution, :map, required: true)

  def distribution_bar_chart(assigns) do
    bars = AnalyticsView.distribution_bars(assigns.distribution, @bar_chart_height)
    has_data = Enum.any?(bars, &(&1.count > 0))
    bar_chart_height = @bar_chart_height
    chart_width = @chart_width
    colors = @stage_css_colors

    assigns =
      assign(assigns,
        bars: bars,
        has_data: has_data,
        bar_chart_height: bar_chart_height,
        chart_width: chart_width,
        colors: colors
      )

    ~H"""
    <div class="bg-base-200 rounded-box p-4 mb-6">
      <h3 class="text-sm font-semibold mb-3">Stage Distribution</h3>
      <%= if @has_data do %>
        <svg
          data-testid="stage-distribution-chart"
          viewBox={"0 0 #{@chart_width} #{@bar_chart_height + 40}"}
          role="img"
          aria-label="Stage distribution"
          class="w-full"
        >
          <%= for bar <- @bars do %>
            <rect
              data-testid={"stage-bar-#{bar.stage}"}
              x={bar.x_position * 90 + 50}
              y={bar.y_offset}
              width="70"
              height={bar.bar_height}
              fill={Map.get(@colors, bar.color, "#6b7280")}
              rx="4"
            />
            <text
              x={bar.x_position * 90 + 85}
              y={@bar_chart_height + 15}
              text-anchor="middle"
              class="fill-base-content text-[10px]"
            >
              {bar.label}
            </text>
            <text
              x={bar.x_position * 90 + 85}
              y={max(bar.y_offset - 5, 12)}
              text-anchor="middle"
              class="fill-base-content text-[11px] font-medium"
            >
              {bar.count}
            </text>
          <% end %>
        </svg>
      <% else %>
        <.empty_state message="No lifecycle data yet" />
      <% end %>
    </div>
    """
  end

  defp stage_css_colors, do: @stage_css_colors

  # Throughput Trend Chart

  attr(:throughput, :list, required: true)
  attr(:buckets, :list, required: true)
  attr(:granularity, :atom, required: true)

  def throughput_trend_chart(assigns) do
    points =
      AnalyticsView.trend_line_points(
        assigns.throughput,
        {@chart_width - 60, @chart_height - 40},
        assigns.buckets
      )

    labels = AnalyticsView.chart_x_labels(assigns.buckets, assigns.granularity)
    has_data = assigns.throughput != []

    assigns =
      assign(assigns,
        points: points,
        labels: labels,
        has_data: has_data,
        chart_width: @chart_width,
        chart_height: @chart_height,
        colors: stage_css_colors()
      )

    ~H"""
    <div class="bg-base-200 rounded-box p-4 mb-6">
      <h3 class="text-sm font-semibold mb-3">Throughput Trend</h3>
      <%= if @has_data do %>
        <svg
          data-testid="throughput-trend-chart"
          viewBox={"0 0 #{@chart_width} #{@chart_height}"}
          role="img"
          aria-label="Throughput trend"
          class="w-full"
        >
          <g transform="translate(40, 10)">
            <%= for {stage, pts} <- @points do %>
              <polyline
                points={pts}
                stroke={Map.get(@colors, stage_color(stage), "#6b7280")}
                fill="none"
                stroke-width="2"
              />
            <% end %>
          </g>
          <%= for {label, i} <- Enum.with_index(@labels) do %>
            <% x = 40 + i * x_step(length(@labels), @chart_width - 60) %>
            <text
              x={x}
              y={@chart_height - 5}
              text-anchor="middle"
              class="fill-base-content text-[9px]"
            >
              {label}
            </text>
          <% end %>
        </svg>
      <% else %>
        <.empty_state message="No throughput data for this period" />
      <% end %>
    </div>
    """
  end

  # Cycle Time Trend Chart

  attr(:cycle_times, :list, required: true)
  attr(:buckets, :list, required: true)
  attr(:granularity, :atom, required: true)

  def cycle_time_trend_chart(assigns) do
    points =
      AnalyticsView.trend_line_points(
        assigns.cycle_times,
        {@chart_width - 60, @chart_height - 40},
        assigns.buckets,
        :avg_seconds
      )

    labels = AnalyticsView.chart_x_labels(assigns.buckets, assigns.granularity)
    has_data = assigns.cycle_times != []

    assigns =
      assign(assigns,
        points: points,
        labels: labels,
        has_data: has_data,
        chart_width: @chart_width,
        chart_height: @chart_height,
        colors: stage_css_colors()
      )

    ~H"""
    <div class="bg-base-200 rounded-box p-4 mb-6">
      <h3 class="text-sm font-semibold mb-3">Cycle Time Trend</h3>
      <%= if @has_data do %>
        <svg
          data-testid="cycle-time-trend-chart"
          viewBox={"0 0 #{@chart_width} #{@chart_height}"}
          role="img"
          aria-label="Cycle time trend"
          class="w-full"
        >
          <g transform="translate(40, 10)">
            <%= for {stage, pts} <- @points do %>
              <polyline
                points={pts}
                stroke={Map.get(@colors, stage_color(stage), "#6b7280")}
                fill="none"
                stroke-width="2"
              />
            <% end %>
          </g>
          <%= for {label, i} <- Enum.with_index(@labels) do %>
            <% x = 40 + i * x_step(length(@labels), @chart_width - 60) %>
            <text
              x={x}
              y={@chart_height - 5}
              text-anchor="middle"
              class="fill-base-content text-[9px]"
            >
              {label}
            </text>
          <% end %>
        </svg>
      <% else %>
        <.empty_state message="No cycle time data for this period" />
      <% end %>
    </div>
    """
  end

  # Granularity Toggle

  attr(:granularity, :atom, required: true)

  def granularity_toggle(assigns) do
    ~H"""
    <div data-testid="granularity-toggle" class="join" role="group">
      <button
        class={"join-item btn btn-sm #{if @granularity == :daily, do: "btn-active"}"}
        aria-pressed={to_string(@granularity == :daily)}
        phx-click="change_granularity"
        phx-value-granularity="daily"
      >
        Daily
      </button>
      <button
        class={"join-item btn btn-sm #{if @granularity == :weekly, do: "btn-active"}"}
        aria-pressed={to_string(@granularity == :weekly)}
        phx-click="change_granularity"
        phx-value-granularity="weekly"
      >
        Weekly
      </button>
      <button
        class={"join-item btn btn-sm #{if @granularity == :monthly, do: "btn-active"}"}
        aria-pressed={to_string(@granularity == :monthly)}
        phx-click="change_granularity"
        phx-value-granularity="monthly"
      >
        Monthly
      </button>
    </div>
    """
  end

  # Date Range Filter

  attr(:date_from, Date, required: true)
  attr(:date_to, Date, required: true)

  def date_range_filter(assigns) do
    ~H"""
    <div data-testid="date-range-filter" class="flex items-center gap-3">
      <input
        data-testid="date-range-start"
        type="date"
        name="date_from"
        value={Date.to_iso8601(@date_from)}
        phx-change="filter_dates"
        class="input input-sm input-bordered"
      />
      <span class="text-sm text-base-content/70">to</span>
      <input
        data-testid="date-range-end"
        type="date"
        name="date_to"
        value={Date.to_iso8601(@date_to)}
        phx-change="filter_dates"
        class="input input-sm input-bordered"
      />
    </div>
    """
  end

  # Empty State

  attr(:message, :string, required: true)

  def empty_state(assigns) do
    ~H"""
    <div class="flex items-center justify-center py-12 text-base-content/50">
      <div class="text-center">
        <.icon name="hero-chart-bar" class="size-8 mx-auto mb-2 opacity-50" />
        <p class="text-sm">{@message}</p>
      </div>
    </div>
    """
  end

  # Helpers

  defp stage_color(stage) do
    TicketLifecyclePolicy.stage_color(stage)
  end

  defp x_step(label_count, width) when label_count > 1, do: width / (label_count - 1)
  defp x_step(_label_count, width), do: width / 2
end
