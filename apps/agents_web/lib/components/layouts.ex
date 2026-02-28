defmodule AgentsWeb.Layouts do
  @moduledoc """
  Layouts for AgentsWeb.

  Provides a minimal layout for the sessions view and an admin layout
  for agent management pages with sidebar navigation.
  When mounted in the Perme8 Dashboard, the dashboard provides its own layout.
  """

  use AgentsWeb, :html

  embed_templates("layouts/*")

  @doc """
  Renders flash messages and connection error notifications.
  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")
  attr(:id, :string, default: "flash-group", doc: "the optional id of flash container")

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Renders the admin layout with sidebar navigation for agent management pages.

  This is a minimal layout for agents_web with sidebar navigation.
  It does NOT include the chat panel or notification bell (those live in jarga_web).

  ## Examples

      <Layouts.admin flash={@flash} current_scope={@current_scope}>
        <h1>Content</h1>
      </Layouts.admin>

  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")

  attr(:current_scope, :map,
    required: true,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"
  )

  slot(:inner_block, required: true)

  def admin(assigns) do
    ~H"""
    <div class="drawer lg:drawer-open h-screen overflow-hidden">
      <input id="admin-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content flex flex-col min-w-0 h-full overflow-hidden">
        <!-- Topbar -->
        <div class="navbar bg-base-100 sticky top-0 z-10">
          <div class="flex-none lg:hidden">
            <label for="admin-drawer" class="btn btn-square btn-ghost">
              <.icon name="hero-bars-3" class="size-6" />
            </label>
          </div>
          <div class="flex-1 min-w-0">
            <span class="text-lg font-semibold ml-2">Agent Management</span>
          </div>
        </div>
        
    <!-- Page content -->
        <main class="flex-1 flex flex-col px-3 sm:px-6 pb-6 pt-0 lg:p-8 overflow-y-auto">
          {render_slot(@inner_block)}
        </main>

        <.flash_group flash={@flash} />
      </div>
      
    <!-- Sidebar -->
      <div class="drawer-side z-20">
        <label for="admin-drawer" aria-label="close sidebar" class="drawer-overlay"></label>
        <aside class="bg-base-200 min-h-full w-80 p-4 flex flex-col">
          <!-- Logo/Brand -->
          <div class="px-4 py-6">
            <span class="text-4xl font-bold">Agents</span>
          </div>
          
    <!-- User info -->
          <div class="px-4 py-4">
            <div class="flex items-center gap-3">
              <div class="avatar placeholder">
                <div class="bg-primary text-primary-content w-10 rounded-full">
                  <span class="text-sm">
                    {String.first(@current_scope.user.email) |> String.upcase()}
                  </span>
                </div>
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium truncate">
                  {@current_scope.user.first_name} {@current_scope.user.last_name}
                </p>
                <p class="text-xs text-base-content/70 truncate">{@current_scope.user.email}</p>
              </div>
            </div>
          </div>
          
    <!-- Navigation -->
          <nav class="flex-1 py-4">
            <ul class="menu gap-1">
              <li>
                <.link navigate={~p"/agents"} class="flex items-center gap-3">
                  <.icon name="hero-cpu-chip" class="size-5" />
                  <span>Agents</span>
                </.link>
              </li>
              <li>
                <.link navigate={~p"/sessions"} class="flex items-center gap-3">
                  <.icon name="hero-command-line" class="size-5" />
                  <span>Sessions</span>
                </.link>
              </li>
            </ul>
          </nav>
          
    <!-- Theme switcher at bottom -->
          <div class="border-t border-base-300 pt-4">
            <div class="px-4">
              <p class="text-xs text-base-content/70 mb-2">Theme</p>
              <.theme_toggle />
            </div>
          </div>
        </aside>
      </div>
    </div>
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  attr(:size, :string,
    default: "md",
    values: ["xs", "sm", "md"],
    doc: "Size of the toggle component"
  )

  def theme_toggle(assigns) do
    {padding, icon_size} =
      case assigns.size do
        "xs" -> {"p-1", "size-3.5"}
        "sm" -> {"p-1.5", "size-3"}
        "md" -> {"p-2", "size-4"}
      end

    assigns =
      assigns
      |> assign(:padding, padding)
      |> assign(:icon_size, icon_size)

    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <button
        class={"flex #{@padding} cursor-pointer w-1/3"}
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="system"
      >
        <.icon
          name="hero-computer-desktop-micro"
          class={"#{@icon_size} opacity-75 hover:opacity-100"}
        />
      </button>

      <button
        class={"flex #{@padding} cursor-pointer w-1/3"}
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
      >
        <.icon name="hero-sun-micro" class={"#{@icon_size} opacity-75 hover:opacity-100"} />
      </button>

      <button
        class={"flex #{@padding} cursor-pointer w-1/3"}
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
      >
        <.icon name="hero-moon-micro" class={"#{@icon_size} opacity-75 hover:opacity-100"} />
      </button>
    </div>
    """
  end
end
