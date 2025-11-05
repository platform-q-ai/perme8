defmodule JargaWeb.AppLive.Pages.Show do
  @moduledoc """
  LiveView for displaying and editing page content with collaborative notes.
  """

  use JargaWeb, :live_view

  alias Jarga.{Pages, Notes, Workspaces, Projects}

  @impl true
  def mount(%{"workspace_slug" => workspace_slug, "page_slug" => page_slug}, _session, socket) do
    user = socket.assigns.current_scope.user

    # Get workspace first
    with {:ok, workspace} <- Workspaces.get_workspace_by_slug(user, workspace_slug),
         {:ok, page} <- get_page_by_slug(user, workspace.id, page_slug),
         {:ok, project} <- get_project_if_exists(user, page),
         {:ok, member} <- Workspaces.get_member(user, workspace.id) do
      # Get the note component (first note in page_components)
      note = Pages.get_page_note(page)

      # Subscribe to page updates via PubSub for collaborative editing
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Jarga.PubSub, "page:#{page.id}")
        Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")
      end

      # Generate user ID for collaborative editing
      collab_user_id = generate_user_id()

      # Determine if the editor should be read-only (guests can only view)
      readonly = member.role == :guest

      {:ok,
       socket
       |> assign(:page, page)
       |> assign(:note, note)
       |> assign(:workspace, workspace)
       |> assign(:project, project)
       |> assign(:current_member, member)
       |> assign(:user_id, collab_user_id)
       |> assign(:editing_title, false)
       |> assign(:readonly, readonly)
       |> assign(:page_form, to_form(%{"title" => page.title}))}
    else
      {:error, _reason} ->
        {:ok,
         socket
         |> put_flash(:error, "Page not found")
         |> redirect(to: ~p"/app/workspaces")}
    end
  end

  @impl true
  def handle_event(
        "yjs_update",
        %{
          "update" => update,
          "complete_state" => complete_state,
          "user_id" => user_id,
          "markdown" => markdown
        },
        socket
      ) do
    page = socket.assigns.page
    note = socket.assigns.note
    current_user = socket.assigns.current_scope.user

    # 1. IMMEDIATELY broadcast the incremental update to other clients
    Phoenix.PubSub.broadcast_from(
      Jarga.PubSub,
      self(),
      "page:#{page.id}",
      {:yjs_update, %{update: update, user_id: user_id}}
    )

    # 2. Send to debouncer for eventual database save (server-side debouncing)
    complete_state_binary = Base.decode64!(complete_state)

    debouncer_pid =
      JargaWeb.PageSaveDebouncer.request_save(
        page.id,
        current_user,
        note.id,
        complete_state_binary,
        markdown
      )

    # In test mode, allow the debouncer to access the database
    if Application.get_env(:jarga, :sql_sandbox) && debouncer_pid do
      Ecto.Adapters.SQL.Sandbox.allow(Jarga.Repo, self(), debouncer_pid)
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "force_save",
        %{"complete_state" => complete_state, "markdown" => markdown},
        socket
      ) do
    note = socket.assigns.note
    current_user = socket.assigns.current_scope.user

    # Force immediate save (bypasses debouncing)
    # Used when user closes tab or switches away
    complete_state_binary = Base.decode64!(complete_state)

    update_attrs = %{
      yjs_state: complete_state_binary,
      note_content: %{"markdown" => markdown}
    }

    case Notes.update_note_via_page(current_user, note.id, update_attrs) do
      {:ok, updated_note} ->
        {:noreply, assign(socket, :note, updated_note)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("awareness_update", %{"update" => update, "user_id" => user_id}, socket) do
    page = socket.assigns.page

    # Broadcast awareness updates to other clients
    Phoenix.PubSub.broadcast_from(
      Jarga.PubSub,
      self(),
      "page:#{page.id}",
      {:awareness_update, %{update: update, user_id: user_id}}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("start_edit_title", _params, socket) do
    {:noreply, assign(socket, :editing_title, true)}
  end

  @impl true
  def handle_event("update_title", %{"page" => %{"title" => title}}, socket) do
    page = socket.assigns.page
    user = socket.assigns.current_scope.user

    case Pages.update_page(user, page.id, %{title: title}) do
      {:ok, updated_page} ->
        {:noreply,
         socket
         |> assign(:page, updated_page)
         |> assign(:editing_title, false)
         |> assign(:page_form, to_form(%{"title" => updated_page.title}))
         |> put_flash(:info, "Page title updated")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to update title")}
    end
  end

  @impl true
  def handle_event("cancel_edit_title", _params, socket) do
    {:noreply, assign(socket, :editing_title, false)}
  end

  @impl true
  def handle_event("toggle_pin", _params, socket) do
    page = socket.assigns.page
    user = socket.assigns.current_scope.user

    case Pages.update_page(user, page.id, %{is_pinned: !page.is_pinned}) do
      {:ok, updated_page} ->
        {:noreply,
         socket
         |> assign(:page, updated_page)
         |> put_flash(:info, if(updated_page.is_pinned, do: "Page pinned", else: "Page unpinned"))}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update pin status")}
    end
  end

  @impl true
  def handle_event("toggle_public", _params, socket) do
    page = socket.assigns.page
    user = socket.assigns.current_scope.user

    case Pages.update_page(user, page.id, %{is_public: !page.is_public}) do
      {:ok, updated_page} ->
        {:noreply,
         socket
         |> assign(:page, updated_page)
         |> put_flash(
           :info,
           if(updated_page.is_public,
             do: "Page is now shared with workspace members",
             else: "Page is now private"
           )
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update sharing status")}
    end
  end

  @impl true
  def handle_event("delete_page", _params, socket) do
    page = socket.assigns.page
    workspace = socket.assigns.workspace
    user = socket.assigns.current_scope.user

    case Pages.delete_page(user, page.id) do
      {:ok, _deleted_page} ->
        {:noreply,
         socket
         |> put_flash(:info, "Page deleted")
         |> push_navigate(to: ~p"/app/workspaces/#{workspace.slug}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete page")}
    end
  end

  @impl true
  def handle_info({:yjs_update, %{update: update, user_id: _user_id}}, socket) do
    # broadcast_from already ensures we don't receive our own messages
    {:noreply, push_event(socket, "yjs_update", %{update: update})}
  end

  @impl true
  def handle_info({:awareness_update, %{update: update, user_id: _user_id}}, socket) do
    # broadcast_from already ensures we don't receive our own messages
    {:noreply, push_event(socket, "awareness_update", %{update: update})}
  end

  @impl true
  def handle_info({:page_visibility_changed, page_id, is_public}, socket) do
    # Update page visibility in real-time when changed by another user
    if socket.assigns.page.id == page_id do
      page = %{socket.assigns.page | is_public: is_public}
      {:noreply, assign(socket, :page, page)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:page_pinned_changed, page_id, is_pinned}, socket) do
    # Update page pinned state in real-time when changed by another user
    if socket.assigns.page.id == page_id do
      page = %{socket.assigns.page | is_pinned: is_pinned}
      {:noreply, assign(socket, :page, page)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:page_title_changed, page_id, title}, socket) do
    # Update page title in the page show view (from another user's edit)
    if socket.assigns.page.id == page_id do
      page = %{socket.assigns.page | title: title}
      page_form = to_form(%{"title" => title})
      {:noreply, socket |> assign(:page, page) |> assign(:page_form, page_form)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:workspace_updated, workspace_id, name}, socket) do
    # Update workspace name in breadcrumbs
    if socket.assigns.workspace.id == workspace_id do
      workspace = %{socket.assigns.workspace | name: name}
      {:noreply, assign(socket, workspace: workspace)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:project_updated, project_id, name}, socket) do
    # Update project name in breadcrumbs
    if socket.assigns.project && socket.assigns.project.id == project_id do
      project = %{socket.assigns.project | name: name}
      {:noreply, assign(socket, project: project)}
    else
      {:noreply, socket}
    end
  end

  defp generate_user_id do
    "user_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"
  end

  defp get_initial_markdown(note) do
    # Try to get markdown from note_content, fallback to empty string
    case note.note_content do
      %{"markdown" => markdown} when is_binary(markdown) -> markdown
      _ -> ""
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope}>
      <div class="h-screen flex flex-col space-y-4">
        <!-- Breadcrumbs -->
        <%= if @project do %>
          <.breadcrumbs>
            <:crumb navigate={~p"/app"}>Home</:crumb>
            <:crumb navigate={~p"/app/workspaces"}>Workspaces</:crumb>
            <:crumb navigate={~p"/app/workspaces/#{@workspace.slug}"}>{@workspace.name}</:crumb>
            <:crumb navigate={~p"/app/workspaces/#{@workspace.slug}/projects/#{@project.slug}"}>
              {@project.name}
            </:crumb>
            <:crumb>{@page.title}</:crumb>
          </.breadcrumbs>
        <% else %>
          <.breadcrumbs>
            <:crumb navigate={~p"/app"}>Home</:crumb>
            <:crumb navigate={~p"/app/workspaces"}>Workspaces</:crumb>
            <:crumb navigate={~p"/app/workspaces/#{@workspace.slug}"}>{@workspace.name}</:crumb>
            <:crumb>{@page.title}</:crumb>
          </.breadcrumbs>
        <% end %>
        
    <!-- Action Buttons (hidden for guests) -->
        <%= if not @readonly do %>
          <div class="flex items-center justify-end gap-2">
            <!-- Share toggle button -->
            <.button
              variant={if @page.is_public, do: "primary", else: "ghost"}
              size="sm"
              phx-click="toggle_public"
            >
              <.icon
                name={if @page.is_public, do: "hero-globe-alt", else: "hero-lock-closed"}
                class="size-4"
              />
              {if @page.is_public, do: "Shared", else: "Private"}
            </.button>
            
    <!-- Pin button -->
            <.button
              variant={if @page.is_pinned, do: "warning", else: "ghost"}
              size="sm"
              phx-click="toggle_pin"
            >
              <.icon name="hero-star" class="size-4" />
              {if @page.is_pinned, do: "Pinned", else: "Pin"}
            </.button>
            
    <!-- Delete button -->
            <.button
              variant="error"
              size="sm"
              phx-click="delete_page"
              data-confirm="Are you sure you want to delete this page?"
            >
              <.icon name="hero-trash" class="size-4" /> Delete
            </.button>
          </div>
        <% end %>
        
    <!-- Title Section -->
        <div class="border-b border-base-300 pb-4">
          <%= if @editing_title do %>
            <form phx-submit="update_title" class="flex items-center gap-2">
              <input
                type="text"
                name="page[title]"
                value={@page_form[:title].value}
                class="flex-1 text-2xl font-bold input input-bordered focus:input-primary"
                autofocus
              />
              <.button type="submit" variant="primary" size="sm">
                Save
              </.button>
              <.button
                type="button"
                variant="ghost"
                size="sm"
                phx-click="cancel_edit_title"
              >
                Cancel
              </.button>
            </form>
          <% else %>
            <h1
              class={[
                "text-2xl font-bold",
                if(@readonly, do: "", else: "cursor-pointer hover:text-primary transition-colors")
              ]}
              phx-click={if @readonly, do: nil, else: "start_edit_title"}
              title={if @readonly, do: nil, else: "Click to edit title"}
            >
              {@page.title}
            </h1>
          <% end %>
        </div>
        
    <!-- Editor -->
        <div class="flex-1 overflow-auto">
          <%= if @readonly do %>
            <div class="alert alert-info mb-4">
              <.icon name="hero-eye" class="size-5" />
              <span>You are viewing this page in read-only mode.</span>
            </div>
          <% end %>
          <div
            id="editor-container"
            phx-hook="MilkdownEditor"
            phx-update="ignore"
            data-yjs-state={if @note.yjs_state, do: Base.encode64(@note.yjs_state), else: ""}
            data-initial-content={get_initial_markdown(@note)}
            data-readonly={if @readonly, do: "true", else: "false"}
            class={[
              "border rounded-lg h-full min-h-[600px]",
              if(@readonly, do: "border-base-300 bg-base-100 opacity-90", else: "border-base-300")
            ]}
          >
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end

  defp get_page_by_slug(user, workspace_id, slug) do
    Pages.get_page_by_slug(user, workspace_id, slug)
  end

  defp get_project_if_exists(user, page) do
    if page.project_id do
      case Projects.get_project(user, page.workspace_id, page.project_id) do
        {:ok, project} -> {:ok, project}
        error -> error
      end
    else
      {:ok, nil}
    end
  end
end
