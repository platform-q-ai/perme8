defmodule ExoDashboardWeb.FeatureComponents do
  @moduledoc """
  UI components for displaying features and scenarios.
  """
  use Phoenix.Component
  import ExoDashboardWeb.CoreComponents

  alias ExoDashboard.Features.Domain.Entities.{Feature, Scenario}

  # ============================================================================
  # Tree components for the dashboard overview
  # ============================================================================

  @doc """
  Renders a collapsible tree group for an app.
  """
  attr(:app_name, :string, required: true)
  attr(:features, :list, required: true)

  def app_tree(assigns) do
    scenario_count =
      Enum.reduce(assigns.features, 0, fn f, acc -> acc + count_scenarios(f) end)

    assigns = assign(assigns, :scenario_count, scenario_count)

    ~H"""
    <details open data-app={@app_name} class="group">
      <summary class="flex items-center gap-2 cursor-pointer select-none py-2 px-3 rounded-lg hover:bg-base-200 transition-colors">
        <.icon
          name="hero-chevron-right"
          class="size-4 text-base-content/40 transition-transform group-open:rotate-90"
        />
        <.icon name="hero-folder" class="size-4 text-warning" />
        <span class="font-semibold">{@app_name}</span>
        <span class="text-xs text-base-content/40">
          {length(@features)} feature{if length(@features) != 1, do: "s"}, {@scenario_count} scenario{if @scenario_count !=
                                                                                                           1,
                                                                                                         do:
                                                                                                           "s"}
        </span>
      </summary>
      <div class="ml-6 border-l border-base-300 pl-1">
        <.feature_tree :for={feature <- @features} feature={feature} />
      </div>
    </details>
    """
  end

  @doc """
  Renders a collapsible tree node for a single feature with its scenarios.
  """
  attr(:feature, Feature, required: true)

  def feature_tree(assigns) do
    scenarios = extract_scenarios(assigns.feature)
    assigns = assign(assigns, :scenarios, scenarios)

    ~H"""
    <details data-feature={@feature.name} class="group/feature">
      <summary class="flex items-center gap-2 cursor-pointer select-none py-1.5 px-3 rounded-lg hover:bg-base-200 transition-colors">
        <.icon
          name="hero-chevron-right"
          class="size-3.5 text-base-content/40 transition-transform group-open/feature:rotate-90"
        />
        <.icon name="hero-document-text" class="size-4 text-base-content/50" />
        <.link
          navigate={"/features/#{encode_uri(@feature.uri)}"}
          class="hover:text-primary transition-colors text-sm"
        >
          {@feature.name}
        </.link>
        <.adapter_badge adapter={@feature.adapter} />
        <span class="text-xs text-base-content/40">
          {length(@scenarios)} scenario{if length(@scenarios) != 1, do: "s"}
        </span>
      </summary>
      <div class="ml-6 border-l border-base-300 pl-1">
        <.scenario_link
          :for={scenario <- @scenarios}
          scenario={scenario}
          feature_uri={@feature.uri}
        />
      </div>
    </details>
    """
  end

  @doc """
  Renders a single scenario as a link that navigates to the feature detail and scrolls to it.
  """
  attr(:scenario, Scenario, required: true)
  attr(:feature_uri, :string, required: true)

  def scenario_link(assigns) do
    anchor = scenario_anchor(assigns.scenario)
    assigns = assign(assigns, :anchor, anchor)

    ~H"""
    <.link
      navigate={"/features/#{encode_uri(@feature_uri)}##{@anchor}"}
      class="flex items-center gap-2 py-1 px-3 rounded-lg hover:bg-base-200 transition-colors text-sm text-base-content/70 hover:text-base-content"
      data-scenario={@scenario.name}
    >
      <.icon name="hero-play" class="size-3 text-base-content/30" />
      {@scenario.name}
      <div :if={@scenario.tags != []} class="flex gap-1 ml-auto">
        <span :for={tag <- @scenario.tags} class="badge badge-outline badge-xs">{tag}</span>
      </div>
    </.link>
    """
  end

  # ============================================================================
  # Legacy card components (kept for reference / potential reuse)
  # ============================================================================

  @doc """
  Renders a group of features for an app.
  """
  attr(:app_name, :string, required: true)
  attr(:features, :list, required: true)

  def app_group(assigns) do
    ~H"""
    <div class="mb-6" data-app={@app_name}>
      <h2 class="text-xl font-bold mb-3 flex items-center gap-2">
        <.icon name="hero-folder" class="size-5" />
        {@app_name}
        <span class="badge badge-neutral badge-sm">{length(@features)}</span>
      </h2>
      <div class="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
        <.feature_card :for={feature <- @features} feature={feature} />
      </div>
    </div>
    """
  end

  @doc """
  Renders a card for a single feature.
  """
  attr(:feature, Feature, required: true)

  def feature_card(assigns) do
    scenario_count = count_scenarios(assigns.feature)
    assigns = assign(assigns, :scenario_count, scenario_count)

    ~H"""
    <div
      class="card bg-base-200 shadow-sm hover:shadow-md transition-shadow"
      data-feature={@feature.name}
    >
      <div class="card-body p-4">
        <h3 class="card-title text-sm">
          <.link
            navigate={"/features/#{encode_uri(@feature.uri)}"}
            class="hover:text-primary transition-colors"
          >
            {@feature.name}
          </.link>
        </h3>
        <div class="flex items-center gap-2 mt-1">
          <.adapter_badge adapter={@feature.adapter} />
          <span class="text-xs text-base-content/60">
            {@scenario_count} scenario{if @scenario_count != 1, do: "s"}
          </span>
        </div>
        <div :if={@feature.tags != []} class="flex flex-wrap gap-1 mt-2">
          <span :for={tag <- @feature.tags} class="badge badge-outline badge-xs">{tag}</span>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a row for a single scenario.
  """
  attr(:scenario, Scenario, required: true)

  def scenario_row(assigns) do
    ~H"""
    <div
      class="flex items-center gap-3 py-2 px-3 rounded-lg hover:bg-base-200"
      data-scenario={@scenario.name}
    >
      <.icon name="hero-document-text" class="size-4 text-base-content/50 shrink-0" />
      <div class="flex-1 min-w-0">
        <p class="text-sm truncate">{@scenario.name}</p>
        <p :if={@scenario.keyword} class="text-xs text-base-content/50">{@scenario.keyword}</p>
      </div>
      <div :if={@scenario.tags != []} class="flex gap-1">
        <span :for={tag <- @scenario.tags} class="badge badge-outline badge-xs">{tag}</span>
      </div>
    </div>
    """
  end

  # ============================================================================
  # Shared components
  # ============================================================================

  @doc """
  Renders an adapter badge (browser, http, security, etc).
  """
  attr(:adapter, :atom, required: true)

  def adapter_badge(assigns) do
    {color, label} = adapter_style(assigns.adapter)
    assigns = assign(assigns, color: color, label: label)

    ~H"""
    <span class={"badge badge-sm #{@color}"} data-adapter={@adapter}>
      {@label}
    </span>
    """
  end

  # ============================================================================
  # Helpers
  # ============================================================================

  defp adapter_style(:browser), do: {"badge-primary", "Browser"}
  defp adapter_style(:http), do: {"badge-secondary", "HTTP"}
  defp adapter_style(:security), do: {"badge-warning", "Security"}
  defp adapter_style(:cli), do: {"badge-accent", "CLI"}
  defp adapter_style(:graph), do: {"badge-info", "Graph"}
  defp adapter_style(_), do: {"badge-ghost", "Unknown"}

  defp count_scenarios(%Feature{children: children}) do
    Enum.reduce(children, 0, fn
      %Scenario{}, acc -> acc + 1
      %{children: nested}, acc -> acc + Enum.count(nested, &match?(%Scenario{}, &1))
      _, acc -> acc
    end)
  end

  @doc false
  def extract_scenarios(%Feature{children: children}) do
    Enum.flat_map(children, fn
      %Scenario{} = s -> [s]
      %{children: nested} -> Enum.filter(nested, &match?(%Scenario{}, &1))
      _ -> []
    end)
  end

  @doc false
  def scenario_anchor(%Scenario{name: name}) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  def scenario_anchor(_), do: ""

  defp encode_uri(nil), do: ""
  defp encode_uri(uri), do: uri
end
