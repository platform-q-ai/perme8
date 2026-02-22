defmodule Perme8DashboardWeb.TabComponents do
  @moduledoc """
  Tab navigation components for Perme8Dashboard.

  Renders a data-driven tab bar where tabs are specified as a list
  of `{key, label, path}` tuples. The active tab receives the
  `tab-active` class.
  """
  use Phoenix.Component

  @doc """
  Renders a tab navigation bar.

  The tabs are data-driven: accepts a list of {key, label, path} tuples.
  The active tab gets the `tab-active` class.

  ## Examples

      <.tab_bar
        tabs={[{:features, "Features", ~p"/"}, {:sessions, "Sessions", ~p"/sessions"}]}
        active_tab={:features}
      />
  """
  attr(:tabs, :list, required: true)
  attr(:active_tab, :atom, required: true)

  def tab_bar(assigns) do
    ~H"""
    <div role="tablist" class="tabs tabs-bordered tabs-lg">
      <.link
        :for={{key, label, path} <- @tabs}
        navigate={path}
        role="tab"
        class={["tab", key == @active_tab && "tab-active"]}
        data-tab={key}
      >
        {label}
      </.link>
    </div>
    """
  end
end
