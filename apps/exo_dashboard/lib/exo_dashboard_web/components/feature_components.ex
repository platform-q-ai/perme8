defmodule ExoDashboardWeb.FeatureComponents do
  @moduledoc """
  UI components for displaying features and scenarios.
  """
  use Phoenix.Component
  import ExoDashboardWeb.CoreComponents

  alias ExoDashboard.Features.Domain.Entities.{Feature, Scenario}

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

  defp encode_uri(nil), do: ""
  defp encode_uri(uri), do: uri
end
