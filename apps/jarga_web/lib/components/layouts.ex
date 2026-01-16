defmodule JargaWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use JargaWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

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
  Renders your admin layout with sidebar.

  This layout is used for authenticated admin/app pages
  and includes a sidebar navigation with links to main sections.

  ## Examples

      <Layouts.admin flash={@flash} current_scope={@current_scope}>
        <h1>Content</h1>
      </Layouts.admin>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    required: true,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  # Optional assigns for chat panel context
  attr :document, :map, default: nil, doc: "current document (optional)"
  attr :note, :map, default: nil, doc: "current note (optional)"
  attr :workspace, :map, default: nil, doc: "current workspace (optional)"
  attr :project, :map, default: nil, doc: "current project (optional)"
  attr :document_title, :string, default: nil, doc: "document title (optional)"

  slot :inner_block, required: true

  slot :breadcrumbs, doc: "breadcrumb items to display in topbar" do
    attr :navigate, :string
    attr :patch, :string
    attr :href, :string
  end

  def admin(assigns) do
    ~H"""
    <div class="drawer lg:drawer-open h-screen overflow-hidden">
      <input id="admin-drawer" type="checkbox" class="drawer-toggle" />
      <div class="drawer-content flex flex-col min-w-0 h-full overflow-hidden">
        <!-- Topbar with breadcrumbs, notification bell, and chat -->
        <div class="navbar bg-base-100 sticky top-0 z-10">
          <div class="flex-none lg:hidden">
            <label for="admin-drawer" class="btn btn-square btn-ghost">
              <.icon name="hero-bars-3" class="size-6" />
            </label>
          </div>
          <div class="flex-1 min-w-0">
            <%= if @workspace || @project || @document || @breadcrumbs != [] do %>
              <nav class="breadcrumbs text-sm overflow-x-auto ml-2 md:ml-4 lg:ml-6">
                <ul class="flex-nowrap">
                  <%= if @breadcrumbs != [] do %>
                    <%= for crumb <- @breadcrumbs do %>
                      <li>
                        <%= if Map.get(crumb, :navigate) do %>
                          <.link navigate={Map.get(crumb, :navigate)} class="hover:underline">
                            {render_slot(crumb)}
                          </.link>
                        <% else %>
                          <span class="text-base-content/70">{render_slot(crumb)}</span>
                        <% end %>
                      </li>
                    <% end %>
                  <% else %>
                    <li>
                      <.link navigate={~p"/app"} class="hover:underline">Home</.link>
                    </li>
                    <%= if @workspace do %>
                      <li>
                        <.link navigate={~p"/app/workspaces"} class="hover:underline">
                          Workspaces
                        </.link>
                      </li>
                      <li>
                        <.link
                          navigate={~p"/app/workspaces/#{@workspace.slug}"}
                          class="hover:underline"
                        >
                          {@workspace.name}
                        </.link>
                      </li>
                    <% end %>
                    <%= if @project do %>
                      <li>
                        <.link
                          navigate={~p"/app/workspaces/#{@workspace.slug}/projects/#{@project.slug}"}
                          class="hover:underline"
                        >
                          {@project.name}
                        </.link>
                      </li>
                    <% end %>
                    <%= if @document do %>
                      <li>
                        <span class="text-base-content/70">{@document.title}</span>
                      </li>
                    <% end %>
                  <% end %>
                </ul>
              </nav>
            <% end %>
          </div>
          <div class="flex-none flex items-center gap-2">
            <.live_component
              module={JargaWeb.NotificationsLive.NotificationBell}
              id="notification-bell-topbar"
              current_user={@current_scope.user}
            />
            <label
              for="chat-drawer-global-chat-panel"
              class="btn btn-ghost btn-circle"
              aria-label="Open chat"
            >
              <.icon name="hero-chat-bubble-left-right" class="size-6" />
            </label>
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
            <.link navigate={~p"/app"} class="flex items-center gap-3">
              <img
                src={~p"/images/j-logo-black.svg"}
                alt="Jarga"
                width="40"
                class="dark:hidden"
              />
              <img
                src={~p"/images/j-logo-white.svg"}
                alt="Jarga"
                width="40"
                class="hidden dark:block"
              />
              <span class="text-4xl font-bold">Jarga</span>
            </.link>
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
                <.link navigate={~p"/app"} class="flex items-center gap-3">
                  <.icon name="hero-home" class="size-5" />
                  <span>Home</span>
                </.link>
              </li>
              <li>
                <.link navigate={~p"/app/workspaces"} class="flex items-center gap-3">
                  <.icon name="hero-briefcase" class="size-5" />
                  <span>Workspaces</span>
                </.link>
              </li>
              <li>
                <.link navigate={~p"/app/agents"} class="flex items-center gap-3">
                  <.icon name="hero-cpu-chip" class="size-5" />
                  <span>Agents</span>
                </.link>
              </li>
              <li>
                <.link navigate={~p"/users/settings"} class="flex items-center gap-3">
                  <.icon name="hero-cog-6-tooth" class="size-5" />
                  <span>Settings</span>
                </.link>
              </li>
              <li>
                <.link href={~p"/users/log-out"} method="delete" class="flex items-center gap-3">
                  <.icon name="hero-arrow-right-on-rectangle" class="size-5" />
                  <span>Log out</span>
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

    <%!-- Global Chat Panel (outside admin drawer) --%>
    <.live_component
      module={JargaWeb.ChatLive.Panel}
      id="global-chat-panel"
      current_user={@current_scope.user}
      current_workspace={@workspace}
      current_project={@project}
      document_title={@document_title}
      note={@note}
      document={@document}
    />
    """
  end

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  attr :size, :string,
    default: "md",
    values: ["xs", "sm", "md"],
    doc: "Size of the toggle component"

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
