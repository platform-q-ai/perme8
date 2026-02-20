defmodule ExoDashboardWeb.DashboardLive do
  @moduledoc """
  Main dashboard view showing all discovered features grouped by app.
  """
  use ExoDashboardWeb, :live_view

  import ExoDashboardWeb.FeatureComponents

  @impl true
  def mount(_params, _session, socket) do
    catalog = discover_features()

    socket =
      socket
      |> assign(:page_title, "Features")
      |> assign(:catalog, catalog)
      |> assign(:filter, :all)
      |> assign(:filtered_apps, catalog.apps)

    {:ok, socket}
  end

  @impl true
  def handle_event("filter", %{"adapter" => "all"}, socket) do
    {:noreply, assign(socket, filter: :all, filtered_apps: socket.assigns.catalog.apps)}
  end

  def handle_event("filter", %{"adapter" => adapter}, socket) do
    adapter_atom = String.to_existing_atom(adapter)

    filtered_apps =
      socket.assigns.catalog.apps
      |> Enum.map(fn {app_name, features} ->
        filtered = Enum.filter(features, &(&1.adapter == adapter_atom))
        {app_name, filtered}
      end)
      |> Enum.reject(fn {_app, features} -> features == [] end)
      |> Map.new()

    {:noreply, assign(socket, filter: adapter_atom, filtered_apps: filtered_apps)}
  end

  def handle_event("refresh", _params, socket) do
    catalog = discover_features()

    socket =
      socket
      |> assign(:catalog, catalog)
      |> assign(:filter, :all)
      |> assign(:filtered_apps, catalog.apps)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:test_run_started, _run_id}, socket) do
    {:noreply, socket}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp discover_features do
    # Allow test injection via Application env
    case Application.get_env(:exo_dashboard, :test_catalog) do
      nil ->
        case ExoDashboard.Features.discover() do
          {:ok, catalog} -> catalog
          {:error, _} -> %{apps: %{}, by_adapter: %{}}
        end

      catalog ->
        catalog
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        Exo Dashboard
        <:subtitle>BDD Feature File Explorer</:subtitle>
        <:actions>
          <div class="flex gap-2">
            <.button phx-click="refresh" data-action="refresh" variant="ghost" size="sm">
              <.icon name="hero-arrow-path" class="size-4" /> Refresh
            </.button>
          </div>
        </:actions>
      </.header>
      
    <!-- Adapter filter buttons -->
      <div class="flex flex-wrap gap-2 mb-6">
        <button
          phx-click="filter"
          phx-value-adapter="all"
          data-filter="all"
          class={"btn btn-sm #{if @filter == :all, do: "btn-primary", else: "btn-ghost"}"}
        >
          All
        </button>
        <button
          :for={adapter <- [:browser, :http, :security, :cli, :graph]}
          phx-click="filter"
          phx-value-adapter={adapter}
          data-filter={adapter}
          class={"btn btn-sm #{if @filter == adapter, do: "btn-primary", else: "btn-ghost"}"}
        >
          {adapter |> Atom.to_string() |> String.capitalize()}
        </button>
      </div>
      
    <!-- Feature groups by app -->
      <div :if={@filtered_apps == %{}} class="text-center py-12 text-base-content/50">
        <.icon name="hero-document-magnifying-glass" class="size-12 mx-auto mb-3" />
        <p>No features found matching the current filter.</p>
      </div>

      <.app_group
        :for={{app_name, features} <- Enum.sort(@filtered_apps)}
        app_name={app_name}
        features={features}
      />
    </div>
    """
  end
end
