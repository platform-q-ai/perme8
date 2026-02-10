defmodule IdentityWeb.ApiKeysLive do
  use IdentityWeb, :live_view

  alias Identity

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="flex items-center justify-between">
          <.header>
            API Keys
            <:subtitle>Manage your API keys for external integrations</:subtitle>
          </.header>

          <.button variant="primary" phx-click="show_create_modal">
            <.icon name="hero-plus" class="size-4" /> New API Key
          </.button>
        </div>

        <%= if Enum.empty?(@all_keys) do %>
          <div class="card bg-base-200">
            <div class="card-body text-center">
              <div class="flex flex-col items-center gap-4 py-8">
                <.icon name="hero-key" class="size-16 opacity-50" />
                <div>
                  <h3 class="text-base font-semibold">No API keys yet</h3>
                  <p class="text-base-content/70">
                    Create your first API key to integrate with external systems
                  </p>
                </div>
                <.button variant="primary" phx-click="show_create_modal">
                  Create API Key
                </.button>
              </div>
            </div>
          </div>
        <% else %>
          <div class="flex gap-2 mb-4">
            <.button
              variant={if(@active_filter == :all, do: "primary", else: "ghost")}
              size="sm"
              phx-click="filter_active"
              phx-value-show="all"
            >
              All ({length(@all_keys)})
            </.button>
            <.button
              variant={if(@active_filter == :active, do: "primary", else: "ghost")}
              size="sm"
              phx-click="filter_active"
              phx-value-show="active"
            >
              Active ({length(@active_keys)})
            </.button>
            <.button
              variant={if(@active_filter == :inactive, do: "primary", else: "ghost")}
              size="sm"
              phx-click="filter_active"
              phx-value-show="inactive"
            >
              Revoked ({length(@inactive_keys)})
            </.button>
          </div>

          <%= if Enum.empty?(@filtered_keys) do %>
            <div class="card bg-base-200">
              <div class="card-body text-center py-8">
                <p class="text-base-content/70">
                  <%= case @active_filter do %>
                    <% :active -> %>
                      No active API keys.
                    <% :inactive -> %>
                      No revoked API keys.
                    <% _ -> %>
                      No API keys found.
                  <% end %>
                </p>
              </div>
            </div>
          <% else %>
            <div class="overflow-x-auto">
              <table class="table table-zebra">
                <thead>
                  <tr>
                    <th class="text-sm font-semibold">Name</th>
                    <th class="text-sm font-semibold">Workspace Access</th>
                    <th class="text-sm font-semibold">Status</th>
                    <th class="text-sm font-semibold">Created</th>
                    <th class="text-sm font-semibold text-right">Actions</th>
                  </tr>
                </thead>
                <tbody>
                  <%= for api_key <- @filtered_keys do %>
                    <tr>
                      <td>
                        <div>
                          <div class="text-sm font-medium">{api_key.name}</div>
                          <%= if api_key.description do %>
                            <div class="text-xs text-base-content/70">{api_key.description}</div>
                          <% end %>
                        </div>
                      </td>
                      <td>
                        <%= if Enum.empty?(api_key.workspace_access) do %>
                          <span class="badge badge-warning badge-sm">No Access</span>
                        <% else %>
                          <div class="flex flex-wrap gap-1">
                            <%= for workspace <- api_key.workspace_access do %>
                              <span class="badge badge-outline badge-sm">{workspace}</span>
                            <% end %>
                          </div>
                        <% end %>
                      </td>
                      <td>
                        <%= if api_key.is_active do %>
                          <span class="badge badge-success badge-sm">Active</span>
                        <% else %>
                          <span class="badge badge-error badge-sm">Revoked</span>
                        <% end %>
                      </td>
                      <td class="text-sm text-base-content/70">
                        {Calendar.strftime(api_key.inserted_at, "%b %d, %Y")}
                      </td>
                      <td class="text-right">
                        <%= if api_key.is_active do %>
                          <div class="join">
                            <.button
                              variant="ghost"
                              size="sm"
                              phx-click="edit_key"
                              phx-value-id={api_key.id}
                              class="join-item"
                            >
                              <.icon name="hero-pencil" class="size-4" />
                            </.button>
                            <.button
                              variant="ghost"
                              size="sm"
                              phx-click="revoke_key"
                              phx-value-id={api_key.id}
                              data-confirm="Are you sure you want to revoke this API key? This action cannot be undone."
                              class="join-item text-error"
                            >
                              <.icon name="hero-trash" class="size-4" />
                            </.button>
                          </div>
                        <% else %>
                          <span class="text-sm text-base-content/50">Revoked</span>
                        <% end %>
                      </td>
                    </tr>
                  <% end %>
                </tbody>
              </table>
            </div>
          <% end %>
        <% end %>
      </div>
      
    <!-- Create Modal -->
      <%= if @show_create_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-4">Create New API Key</h3>
            <.form for={@create_form} id="create_form" phx-submit="create_key">
              <div class="space-y-4">
                <.input
                  field={@create_form[:name]}
                  type="text"
                  label="Name"
                  placeholder="e.g., Production API Key"
                  required
                />
                <.input
                  field={@create_form[:description]}
                  type="text"
                  label="Description"
                  placeholder="Describe the purpose of this key"
                />

                <div class="form-control">
                  <label class="label">
                    <span class="label-text font-medium">Workspace Access</span>
                  </label>
                  <p class="text-xs text-base-content/70 mb-2">
                    Select which workspaces this key can access. If none are selected, the key will have no access.
                  </p>
                  <%= if Enum.empty?(@available_workspaces) do %>
                    <p class="text-sm text-base-content/50 py-2">
                      No workspaces available. The key will have no workspace access.
                    </p>
                  <% else %>
                    <div class="flex flex-wrap gap-3">
                      <%= for workspace <- @available_workspaces do %>
                        <label class="label cursor-pointer gap-2 p-0">
                          <input
                            type="checkbox"
                            name="workspace_access[]"
                            value={workspace.slug}
                            checked={workspace.slug in @selected_workspaces}
                            phx-click="toggle_workspace"
                            phx-value-workspace={workspace.slug}
                            class="checkbox checkbox-sm checkbox-primary"
                          />
                          <span class="label-text">{workspace.name}</span>
                        </label>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>

              <div class="modal-action">
                <.button type="button" variant="ghost" phx-click="cancel_create">
                  Cancel
                </.button>
                <.button variant="primary" phx-disable-with="Creating...">
                  Create API Key
                </.button>
              </div>
            </.form>
          </div>
          <div class="modal-backdrop" phx-click="cancel_create"></div>
        </div>
      <% end %>
      
    <!-- Edit Modal -->
      <%= if @show_edit_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <h3 class="font-bold text-lg mb-4">Edit API Key</h3>
            <.form for={@edit_form} id="edit_form" phx-submit="update_key">
              <input type="hidden" name="api_key_id" value={@editing_key_id} />
              <div class="space-y-4">
                <.input field={@edit_form[:name]} type="text" label="Name" required />
                <.input field={@edit_form[:description]} type="text" label="Description" />

                <div class="form-control">
                  <label class="label">
                    <span class="label-text font-medium">Workspace Access</span>
                  </label>
                  <%= if Enum.empty?(@available_workspaces) do %>
                    <p class="text-sm text-base-content/50 py-2">
                      No workspaces available.
                    </p>
                  <% else %>
                    <div class="flex flex-wrap gap-3">
                      <%= for workspace <- @available_workspaces do %>
                        <label class="label cursor-pointer gap-2 p-0">
                          <input
                            type="checkbox"
                            name="workspace_access[]"
                            value={workspace.slug}
                            checked={workspace.slug in @selected_workspaces}
                            phx-click="toggle_workspace_edit"
                            phx-value-workspace={workspace.slug}
                            class="checkbox checkbox-sm checkbox-primary"
                          />
                          <span class="label-text">{workspace.name}</span>
                        </label>
                      <% end %>
                    </div>
                  <% end %>
                </div>
              </div>

              <div class="modal-action">
                <.button type="button" variant="ghost" phx-click="cancel_edit">
                  Cancel
                </.button>
                <.button variant="primary" phx-disable-with="Saving...">
                  Save Changes
                </.button>
              </div>
            </.form>
          </div>
          <div class="modal-backdrop" phx-click="cancel_edit"></div>
        </div>
      <% end %>
      
    <!-- Token Display Modal -->
      <%= if @show_token_modal do %>
        <div class="modal modal-open">
          <div class="modal-box">
            <div class="text-center">
              <div class="flex justify-center mb-4">
                <div class="bg-warning/20 p-4 rounded-full">
                  <.icon name="hero-key" class="size-12 text-warning" />
                </div>
              </div>
              <h3 class="font-bold text-lg mb-2">Your API Key</h3>
              <p class="text-sm text-base-content/70 mb-4">
                Copy this key now. For security reasons, it won't be shown again.
              </p>

              <div class="bg-base-200 rounded-lg p-4 mb-4">
                <code
                  id="api_key_token"
                  class="text-sm break-all font-mono select-all"
                  phx-hook="CopyToClipboard"
                >
                  {@new_token}
                </code>
              </div>

              <.button
                variant="ghost"
                size="sm"
                phx-click={JS.dispatch("phx:copy", to: "#api_key_token")}
                class="mb-4"
              >
                <.icon name="hero-clipboard-document" class="size-4 mr-1" /> Copy to clipboard
              </.button>

              <div class="alert alert-warning text-left">
                <.icon name="hero-exclamation-triangle" class="size-5 shrink-0" />
                <div>
                  <p class="font-semibold text-sm">Store this key securely</p>
                  <p class="text-xs">If you lose it, you'll need to create a new one.</p>
                </div>
              </div>

              <div class="modal-action justify-center">
                <.button variant="primary" phx-click="close_token_modal">
                  I've copied the key
                </.button>
              </div>
            </div>
          </div>
        </div>
      <% end %>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_user = current_user(socket)

    # Get user's workspaces - this requires cross-app communication
    # For now, use an empty list or call Jarga.Workspaces if available
    available_workspaces = get_user_workspaces(current_user)

    # Load user's API keys
    {:ok, all_keys} = Identity.list_api_keys(current_user.id)
    active_keys = Enum.filter(all_keys, & &1.is_active)
    inactive_keys = Enum.filter(all_keys, &(!&1.is_active))
    filtered_keys = all_keys

    # Initialize forms
    create_form = to_form(%{"name" => "", "description" => ""})
    edit_form = to_form(%{"name" => "", "description" => ""})

    socket =
      socket
      |> assign(:page_title, "API Keys")
      |> assign(:current_user, current_user)
      |> assign(:available_workspaces, available_workspaces)
      |> assign(:all_keys, all_keys)
      |> assign(:active_keys, active_keys)
      |> assign(:inactive_keys, inactive_keys)
      |> assign(:filtered_keys, filtered_keys)
      |> assign(:active_filter, :all)
      |> assign(:selected_workspaces, [])
      |> assign(:create_form, create_form)
      |> assign(:edit_form, edit_form)
      |> assign(:show_create_modal, false)
      |> assign(:show_edit_modal, false)
      |> assign(:show_token_modal, false)
      |> assign(:new_token, nil)
      |> assign(:editing_key_id, nil)

    {:ok, socket}
  end

  # Show create modal
  @impl true
  def handle_event("show_create_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_create_modal, true)
      |> assign(:selected_workspaces, [])
      |> assign(:create_form, to_form(%{"name" => "", "description" => ""}))

    {:noreply, socket}
  end

  # Cancel create
  @impl true
  def handle_event("cancel_create", _params, socket) do
    socket =
      socket
      |> assign(:show_create_modal, false)
      |> assign(:selected_workspaces, [])

    {:noreply, socket}
  end

  # Handle create API key
  @impl true
  def handle_event("create_key", %{"name" => name, "description" => description} = attrs, socket) do
    workspace_access = get_selected_workspaces(attrs)

    api_key_attrs = %{
      name: name,
      description: description,
      workspace_access: workspace_access
    }

    case Identity.create_api_key(current_user(socket).id, api_key_attrs) do
      {:ok, {_api_key, plain_token}} ->
        # Reload API keys list
        {:ok, all_keys} = Identity.list_api_keys(current_user(socket).id)
        active_keys = Enum.filter(all_keys, & &1.is_active)
        inactive_keys = Enum.filter(all_keys, &(!&1.is_active))

        # Show token modal
        socket =
          socket
          |> put_flash(:info, "API key created successfully!")
          |> assign(:all_keys, all_keys)
          |> assign(:active_keys, active_keys)
          |> assign(:inactive_keys, inactive_keys)
          |> assign(:filtered_keys, all_keys)
          |> assign(:active_filter, :all)
          |> assign(:show_create_modal, false)
          |> assign(:show_token_modal, true)
          |> assign(:new_token, plain_token)
          |> assign(:create_form, to_form(%{"name" => "", "description" => ""}))
          |> assign(:selected_workspaces, [])

        {:noreply, socket}

      {:error, :forbidden} ->
        socket =
          socket
          |> put_flash(:error, "You don't have access to one or more of the selected workspaces.")

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(:error, "Failed to create API key: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  # Handle edit key
  @impl true
  def handle_event("edit_key", %{"id" => api_key_id}, socket) do
    case find_api_key(socket.assigns.all_keys, api_key_id) do
      nil ->
        socket =
          socket
          |> put_flash(:error, "API key not found.")

        {:noreply, socket}

      api_key ->
        edit_form =
          to_form(%{
            "name" => api_key.name,
            "description" => api_key.description || ""
          })

        socket =
          socket
          |> assign(:edit_form, edit_form)
          |> assign(:show_edit_modal, true)
          |> assign(:editing_key_id, api_key_id)
          |> assign(:selected_workspaces, api_key.workspace_access)

        {:noreply, socket}
    end
  end

  # Handle update key
  @impl true
  def handle_event(
        "update_key",
        %{"api_key_id" => api_key_id, "name" => name, "description" => description} = attrs,
        socket
      ) do
    workspace_access = get_selected_workspaces(attrs)

    update_attrs = %{
      name: name,
      description: description,
      workspace_access: workspace_access
    }

    case Identity.update_api_key(current_user(socket).id, api_key_id, update_attrs) do
      {:ok, _updated_key} ->
        # Reload API keys list
        {:ok, all_keys} = Identity.list_api_keys(current_user(socket).id)
        active_keys = Enum.filter(all_keys, & &1.is_active)
        inactive_keys = Enum.filter(all_keys, &(!&1.is_active))

        socket =
          socket
          |> put_flash(:info, "API key updated successfully!")
          |> assign(:all_keys, all_keys)
          |> assign(:active_keys, active_keys)
          |> assign(:inactive_keys, inactive_keys)
          |> assign(:filtered_keys, filter_keys_by_status(all_keys, socket.assigns.active_filter))
          |> assign(:show_edit_modal, false)
          |> assign(:editing_key_id, nil)

        {:noreply, socket}

      {:error, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "API key not found.")

        {:noreply, socket}

      {:error, :forbidden} ->
        socket =
          socket
          |> put_flash(:error, "You don't have access to one or more of the selected workspaces.")

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(:error, "Failed to update API key: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  # Handle cancel edit
  @impl true
  def handle_event("cancel_edit", _params, socket) do
    socket =
      socket
      |> assign(:show_edit_modal, false)
      |> assign(:editing_key_id, nil)
      |> assign(:selected_workspaces, [])

    {:noreply, socket}
  end

  # Handle revoke key
  @impl true
  def handle_event("revoke_key", %{"id" => api_key_id}, socket) do
    case Identity.revoke_api_key(current_user(socket).id, api_key_id) do
      {:ok, _revoked_key} ->
        # Reload API keys list
        {:ok, all_keys} = Identity.list_api_keys(current_user(socket).id)
        active_keys = Enum.filter(all_keys, & &1.is_active)
        inactive_keys = Enum.filter(all_keys, &(!&1.is_active))

        socket =
          socket
          |> put_flash(:info, "API key revoked successfully!")
          |> assign(:all_keys, all_keys)
          |> assign(:active_keys, active_keys)
          |> assign(:inactive_keys, inactive_keys)
          |> assign(:filtered_keys, filter_keys_by_status(all_keys, socket.assigns.active_filter))

        {:noreply, socket}

      {:error, :not_found} ->
        socket =
          socket
          |> put_flash(:error, "API key not found.")

        {:noreply, socket}

      {:error, :forbidden} ->
        socket =
          socket
          |> put_flash(:error, "You don't have permission to revoke this API key.")

        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> put_flash(:error, "Failed to revoke API key: #{inspect(reason)}")

        {:noreply, socket}
    end
  end

  # Handle filter keys
  @impl true
  def handle_event("filter_active", %{"show" => filter}, socket) do
    active_filter = String.to_atom(filter)
    filtered_keys = filter_keys_by_status(socket.assigns.all_keys, active_filter)

    socket =
      socket
      |> assign(:active_filter, active_filter)
      |> assign(:filtered_keys, filtered_keys)

    {:noreply, socket}
  end

  # Handle toggle workspace checkbox (create mode)
  @impl true
  def handle_event("toggle_workspace", %{"workspace" => workspace}, socket) do
    current_selected = socket.assigns.selected_workspaces

    new_selected =
      if workspace in current_selected do
        Enum.reject(current_selected, &(&1 == workspace))
      else
        [workspace | current_selected]
      end

    socket = assign(socket, :selected_workspaces, new_selected)
    {:noreply, socket}
  end

  # Handle toggle workspace checkbox (edit mode)
  @impl true
  def handle_event("toggle_workspace_edit", %{"workspace" => workspace}, socket) do
    current_selected = socket.assigns.selected_workspaces

    new_selected =
      if workspace in current_selected do
        Enum.reject(current_selected, &(&1 == workspace))
      else
        [workspace | current_selected]
      end

    socket = assign(socket, :selected_workspaces, new_selected)
    {:noreply, socket}
  end

  # Handle close token modal
  @impl true
  def handle_event("close_token_modal", _params, socket) do
    socket =
      socket
      |> assign(:show_token_modal, false)
      |> assign(:new_token, nil)

    {:noreply, socket}
  end

  # Private helper functions

  defp get_user_workspaces(user) do
    # Cross-app communication: call Jarga.Workspaces if available
    # Uses apply/3 to avoid compile-time warning since Jarga.Workspaces
    # is in a different app that may not be available during compilation
    if Code.ensure_loaded?(Jarga.Workspaces) and
         function_exported?(Jarga.Workspaces, :list_workspaces_for_user, 1) do
      # credo:disable-for-next-line Credo.Check.Refactor.Apply
      apply(Jarga.Workspaces, :list_workspaces_for_user, [user])
    else
      []
    end
  end

  defp get_selected_workspaces(params) do
    case Map.get(params, "workspace_access") do
      nil -> []
      "" -> []
      value when is_list(value) -> value
      value -> [value]
    end
  end

  defp find_api_key(api_keys, api_key_id) do
    Enum.find(api_keys, &(&1.id == api_key_id))
  end

  defp filter_keys_by_status(keys, :active), do: Enum.filter(keys, & &1.is_active)
  defp filter_keys_by_status(keys, :inactive), do: Enum.filter(keys, &(!&1.is_active))
  defp filter_keys_by_status(keys, _), do: keys

  defp current_user(socket), do: socket.assigns.current_scope.user
end
