defmodule Perme8DashboardWeb.Hooks.SetActiveTab do
  @moduledoc """
  LiveView on_mount hook that sets the active tab based on the current URL path.

  Used by the tab bar navigation to highlight the correct tab.

  ## Usage

  Add to a `live_session` in the router:

      live_session :dashboard,
        on_mount: [{Perme8DashboardWeb.Hooks.SetActiveTab, :default}] do
        ...
      end

  ## Assigned values

    * `:active_tab` — atom identifying the current tab (`:features` or `:sessions`)
  """

  import Phoenix.LiveView
  import Phoenix.Component, only: [assign: 3]

  @doc """
  Called once when the LiveView mounts. Sets the default active tab and attaches
  a `handle_params` hook so the active tab updates on navigation.
  """
  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> assign(:active_tab, :features)
     |> attach_hook(:set_active_tab, :handle_params, &set_tab_from_uri/3)}
  end

  defp set_tab_from_uri(_params, uri, socket) do
    path = URI.parse(uri).path

    active_tab =
      if String.starts_with?(path, "/sessions"), do: :sessions, else: :features

    {:cont, assign(socket, :active_tab, active_tab)}
  end
end
