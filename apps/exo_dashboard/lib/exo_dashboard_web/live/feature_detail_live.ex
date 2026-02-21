defmodule ExoDashboardWeb.FeatureDetailLive do
  @moduledoc """
  Detail view for a single feature, showing scenarios and steps.
  """
  use ExoDashboardWeb, :live_view

  import ExoDashboardWeb.FeatureComponents

  alias ExoDashboard.Features.Domain.Entities.{Feature, Scenario, Rule}

  @impl true
  def mount(%{"uri" => uri_parts}, _session, socket) do
    uri = "/" <> Enum.join(uri_parts, "/")

    socket =
      socket
      |> assign(:page_title, "Loading...")
      |> assign(:feature, nil)
      |> assign(:loading, true)
      |> assign(:uri, uri)

    send(self(), :load_features)

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_features, socket) do
    catalog = discover_features()
    feature = find_feature(catalog, socket.assigns.uri)

    socket =
      socket
      |> assign(:page_title, (feature && feature.name) || "Feature Not Found")
      |> assign(:feature, feature)
      |> assign(:loading, false)

    {:noreply, socket}
  end

  defp find_feature(catalog, uri) do
    catalog.apps
    |> Map.values()
    |> List.flatten()
    |> Enum.find(fn %Feature{uri: feature_uri} -> feature_uri == uri end)
  end

  defp discover_features do
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
      <.back navigate={~p"/"}>Back to dashboard</.back>

      <div :if={@loading} class="text-center py-12 text-base-content/50">
        <.icon name="hero-arrow-path" class="size-12 mx-auto mb-3 animate-spin" />
        <p>Loading feature...</p>
      </div>

      <div :if={!@loading && @feature} id="feature-detail" phx-hook="ScrollToHash" class="mt-6">
        <.header>
          {@feature.name}
          <:subtitle>
            <span :if={@feature.description} class="text-sm text-base-content/60 whitespace-pre-line">
              {String.trim(@feature.description)}
            </span>
          </:subtitle>
          <:actions>
            <.adapter_badge adapter={@feature.adapter} />
          </:actions>
        </.header>

        <div :if={@feature.tags != []} class="flex flex-wrap gap-1 mb-4">
          <span :for={tag <- @feature.tags} class="badge badge-outline badge-sm">{tag}</span>
        </div>
        
    <!-- Feature children (scenarios and rules) -->
        <div class="space-y-6">
          <.render_child :for={child <- @feature.children} child={child} />
        </div>
      </div>

      <div :if={!@loading && !@feature} class="text-center py-12 text-base-content/50">
        <.icon name="hero-exclamation-triangle" class="size-12 mx-auto mb-3" />
        <p>Feature not found: {@uri}</p>
      </div>
    </div>
    """
  end

  defp render_child(%{child: %Scenario{}} = assigns) do
    anchor = ExoDashboardWeb.FeatureComponents.scenario_anchor(assigns.child)
    assigns = assign(assigns, :anchor, anchor)

    ~H"""
    <div id={@anchor} class="card bg-base-200 p-4 scroll-mt-20" data-scenario={@child.name}>
      <h3 class="font-semibold text-sm mb-2">
        <span class="text-base-content/50">{@child.keyword}:</span>
        {@child.name}
      </h3>
      <div :if={@child.tags != []} class="flex flex-wrap gap-1 mb-2">
        <span :for={tag <- @child.tags} class="badge badge-outline badge-xs">{tag}</span>
      </div>
      <div class="space-y-1 ml-4">
        <div :for={step <- @child.steps} class="flex gap-2 text-sm">
          <span class="text-primary font-mono whitespace-nowrap">{String.trim(step.keyword)}</span>
          <span class="text-base-content/80">{step.text}</span>
        </div>
      </div>
    </div>
    """
  end

  defp render_child(%{child: %Rule{}} = assigns) do
    ~H"""
    <div class="border-l-2 border-primary/30 pl-4" data-rule={@child.name}>
      <h3 class="font-bold text-base mb-3">
        <.icon name="hero-shield-check" class="size-4 inline" /> Rule: {@child.name}
      </h3>
      <div class="space-y-4">
        <.render_child :for={child <- @child.children} child={child} />
      </div>
    </div>
    """
  end

  defp render_child(assigns) do
    ~H"""
    """
  end
end
