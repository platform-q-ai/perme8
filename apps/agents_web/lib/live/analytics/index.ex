defmodule AgentsWeb.AnalyticsLive.Index do
  @moduledoc """
  LiveView for the ticket lifecycle analytics dashboard.

  Displays summary counter cards, stage distribution bar chart,
  throughput and cycle time trend charts with time granularity
  toggle and date range filtering. Updates in real time when
  ticket stage changes occur.
  """

  use AgentsWeb, :live_view

  import AgentsWeb.AnalyticsLive.Components.ChartComponents

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "sessions:tickets")
      Perme8.Events.subscribe("events:tickets")
    end

    date_to = Date.utc_today()
    date_from = Date.add(date_to, -30)

    socket =
      socket
      |> assign(:page_title, "Analytics")
      |> assign(:granularity, :daily)
      |> assign(:date_from, date_from)
      |> assign(:date_to, date_to)
      |> load_analytics()

    {:ok, socket}
  end

  @impl true
  def handle_event("change_granularity", %{"granularity" => granularity}, socket) do
    granularity = String.to_existing_atom(granularity)

    socket =
      socket
      |> assign(:granularity, granularity)
      |> load_analytics()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_dates", params, socket) do
    date_from_str = params["date_from"] || params["value"]
    date_to_str = params["date_to"] || Date.to_iso8601(socket.assigns.date_to)

    with {:ok, date_from} <- Date.from_iso8601(date_from_str || ""),
         {:ok, date_to} <- Date.from_iso8601(date_to_str || "") do
      socket =
        socket
        |> assign(:date_from, date_from)
        |> assign(:date_to, date_to)
        |> load_analytics()

      {:noreply, socket}
    else
      _ ->
        {:noreply, put_flash(socket, :error, "Invalid date format")}
    end
  end

  @impl true
  def handle_info(%Agents.Tickets.Domain.Events.TicketStageChanged{}, socket) do
    {:noreply, load_analytics(socket)}
  end

  @impl true
  def handle_info({:ticket_stage_changed, _ticket_id, _stage, _at}, socket) do
    {:noreply, load_analytics(socket)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp load_analytics(socket) do
    opts = [
      date_from: socket.assigns.date_from,
      date_to: socket.assigns.date_to,
      granularity: socket.assigns.granularity
    ]

    case Agents.Tickets.get_analytics(opts) do
      {:ok, analytics} ->
        empty? =
          analytics.summary.total == 0 &&
            analytics.throughput == [] &&
            analytics.cycle_times == []

        socket
        |> assign(:analytics, analytics)
        |> assign(:empty?, empty?)

      _ ->
        socket
        |> assign(:analytics, empty_analytics(socket.assigns))
        |> assign(:empty?, true)
    end
  end

  defp empty_analytics(assigns) do
    %{
      summary: %{total: 0, open: 0, avg_cycle_time_seconds: nil, completed: 0},
      distribution: %{
        "open" => 0,
        "ready" => 0,
        "in_progress" => 0,
        "in_review" => 0,
        "ci_testing" => 0,
        "deployed" => 0,
        "closed" => 0
      },
      throughput: [],
      cycle_times: [],
      buckets: [],
      granularity: assigns.granularity,
      date_from: assigns.date_from,
      date_to: assigns.date_to
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <AgentsWeb.Layouts.admin current_scope={@current_scope} flash={@flash}>
      <div class="max-w-6xl mx-auto">
        <div class="flex flex-col sm:flex-row items-start sm:items-center justify-between mb-6 gap-4">
          <h1 class="text-2xl font-bold">Analytics</h1>
          <div class="flex items-center gap-4 flex-wrap">
            <.granularity_toggle granularity={@granularity} />
            <.date_range_filter date_from={@date_from} date_to={@date_to} />
          </div>
        </div>

        <.summary_cards summary={@analytics.summary} />

        <%= if @empty? do %>
          <div class="bg-base-200 rounded-box p-8">
            <.empty_state message="No lifecycle data yet" />
          </div>
        <% else %>
          <.distribution_bar_chart distribution={@analytics.distribution} />
          <.throughput_trend_chart
            throughput={@analytics.throughput}
            buckets={@analytics.buckets}
            granularity={@granularity}
          />
          <.cycle_time_trend_chart
            cycle_times={@analytics.cycle_times}
            buckets={@analytics.buckets}
            granularity={@granularity}
          />
        <% end %>
      </div>
    </AgentsWeb.Layouts.admin>
    """
  end
end
