defmodule JargaWeb.AppLive.Pages.Show do
  use JargaWeb, :live_view

  alias Jarga.{Pages, Notes, Workspaces, Projects}

  @impl true
  def mount(%{"workspace_slug" => workspace_slug, "page_slug" => page_slug}, _session, socket) do
    user = socket.assigns.current_scope.user

    # Get workspace first
    workspace = Workspaces.get_workspace_by_slug!(user, workspace_slug)

    # Get the page by slug (will raise if not found or unauthorized)
    # Preload page_components
    page = Pages.get_page_by_slug!(user, workspace.id, page_slug)
    |> Jarga.Repo.preload(:page_components)

    # Get project context if applicable
    project = if page.project_id do
      Projects.get_project!(user, page.workspace_id, page.project_id)
    else
      nil
    end

    # Get the note component (first note in page_components)
    note = get_note_component(page)

    # Subscribe to page updates via PubSub for collaborative editing
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Jarga.PubSub, "page:#{page.id}")
    end

    # Generate user ID for collaborative editing
    collab_user_id = generate_user_id()

    {:ok,
     socket
     |> assign(:page, page)
     |> assign(:note, note)
     |> assign(:workspace, workspace)
     |> assign(:project, project)
     |> assign(:user_id, collab_user_id)
     |> assign(:editing_title, false)
     |> assign(:page_form, to_form(%{"title" => page.title}))}
  end

  @impl true
  def handle_event("yjs_update", %{"update" => update, "user_id" => user_id}, socket) do
    page = socket.assigns.page

    # ONLY broadcast the incremental update to other clients
    # DO NOT save to database here - that's handled by the debounced save_note event
    Phoenix.PubSub.broadcast_from(
      Jarga.PubSub,
      self(),
      "page:#{page.id}",
      {:yjs_update, %{update: update, user_id: user_id}}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("save_note", %{"complete_state" => complete_state, "markdown" => markdown}, socket) do
    note = socket.assigns.note
    current_user = socket.assigns.current_scope.user

    # This is the debounced save - only happens after user stops typing
    complete_state_binary = Base.decode64!(complete_state)

    # Update the note with complete yjs state and markdown content
    update_attrs = %{
      yjs_state: complete_state_binary,
      note_content: %{"markdown" => markdown}
    }

    case Notes.update_note(current_user, note.id, update_attrs) do
      {:ok, updated_note} ->
        # Update socket assigns with new note
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
         |> put_flash(:info, if(updated_page.is_public, do: "Page is now shared with workspace members", else: "Page is now private"))}

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

  defp get_note_component(page) do
    # Get the first note component from page_components
    case Enum.find(page.page_components, fn pc -> pc.component_type == "note" end) do
      %{component_id: note_id} ->
        Jarga.Repo.get!(Jarga.Notes.Note, note_id)

      nil ->
        raise "Page has no note component"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin flash={@flash} current_scope={@current_scope}>
      <div class="h-screen flex flex-col">
        <!-- Header -->
        <div class="bg-gray-800 text-white p-4 flex items-center justify-between">
          <div class="flex items-center space-x-4">
            <!-- Breadcrumb -->
            <nav class="flex items-center space-x-2 text-sm">
              <.link navigate={~p"/app/workspaces"} class="hover:underline">
                Workspaces
              </.link>
              <span>/</span>
              <.link navigate={~p"/app/workspaces/#{@workspace.slug}"} class="hover:underline">
                {@workspace.name}
              </.link>
              <%= if @project do %>
                <span>/</span>
                <.link navigate={~p"/app/workspaces/#{@workspace.slug}/projects/#{@project.slug}"} class="hover:underline">
                  {@project.name}
                </.link>
              <% end %>
              <span>/</span>
              <span class="text-gray-300">Page</span>
            </nav>
          </div>

          <div class="flex items-center space-x-4">
            <!-- Share toggle button -->
            <button
              type="button"
              phx-click="toggle_public"
              class={"px-3 py-1 rounded text-sm " <> if @page.is_public, do: "bg-green-600 text-white", else: "bg-gray-600 text-gray-300 hover:bg-gray-500"}
            >
              <%= if @page.is_public, do: "🌐 Shared", else: "🔒 Private" %>
            </button>

            <!-- Pin button -->
            <button
              type="button"
              phx-click="toggle_pin"
              class={"px-3 py-1 rounded text-sm " <> if @page.is_pinned, do: "bg-yellow-500 text-white", else: "bg-gray-600 text-gray-300 hover:bg-gray-500"}
            >
              <%= if @page.is_pinned, do: "📌 Pinned", else: "📌 Pin" %>
            </button>

            <!-- Delete button -->
            <button
              type="button"
              phx-click="delete_page"
              data-confirm="Are you sure you want to delete this page?"
              class="px-3 py-1 bg-red-600 hover:bg-red-700 text-white rounded text-sm"
            >
              Delete
            </button>
          </div>
        </div>

        <!-- Title Section -->
        <div class="bg-white border-b px-6 py-4">
          <%= if @editing_title do %>
            <form phx-submit="update_title" class="flex items-center space-x-2">
              <input
                type="text"
                name="page[title]"
                value={@page_form[:title].value}
                class="flex-1 text-2xl font-bold border-b-2 border-blue-500 focus:outline-none"
                autofocus
              />
              <button type="submit" class="px-3 py-1 bg-blue-500 text-white rounded text-sm">
                Save
              </button>
              <button
                type="button"
                phx-click="cancel_edit_title"
                class="px-3 py-1 bg-gray-300 text-gray-700 rounded text-sm"
              >
                Cancel
              </button>
            </form>
          <% else %>
            <h1
              class="text-2xl font-bold cursor-pointer hover:text-blue-600"
              phx-click="start_edit_title"
            >
              {@page.title}
            </h1>
          <% end %>
        </div>

        <!-- Editor -->
        <div class="flex-1 p-6 overflow-auto">
          <div
            id="editor-container"
            phx-hook="MilkdownEditor"
            phx-update="ignore"
            data-yjs-state={if @note.yjs_state, do: Base.encode64(@note.yjs_state), else: ""}
            data-initial-content={get_initial_markdown(@note)}
            class="border border-gray-300 rounded-lg h-full min-h-[600px]"
          >
          </div>
        </div>
      </div>
    </Layouts.admin>
    """
  end
end
