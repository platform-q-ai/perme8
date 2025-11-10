defmodule JargaWeb.AppLive.Pages.Show do
  @moduledoc """
  LiveView for displaying and editing page content with collaborative notes.
  """

  use JargaWeb, :live_view

  import JargaWeb.ChatLive.MessageHandlers

  alias Jarga.{Pages, Notes, Workspaces, Projects, Documents}
  alias Ecto.Adapters.SQL.Sandbox

  @impl true
  def mount(%{"workspace_slug" => workspace_slug, "page_slug" => page_slug}, _session, socket) do
    user = socket.assigns.current_scope.user

    # Optimized: get workspace and member in single query
    with {:ok, workspace, member} <-
           Workspaces.get_workspace_and_member_by_slug(user, workspace_slug),
         {:ok, page} <- get_page_by_slug(user, workspace.id, page_slug),
         {:ok, project} <- get_project_if_exists(user, page) do
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
      Sandbox.allow(Jarga.Repo, self(), debouncer_pid)
    end

    # 3. Update socket assigns with latest state so get_current_yjs_state returns fresh data
    # This prevents false "out of sync" warnings before the debouncer saves to DB
    updated_note = %{
      note
      | yjs_state: complete_state_binary,
        note_content: %{"markdown" => markdown}
    }

    {:noreply, assign(socket, :note, updated_note)}
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
  def handle_event("get_current_yjs_state", _params, socket) do
    note = socket.assigns.note

    # Return current yjs_state from database
    {:reply, %{yjs_state: Base.encode64(note.yjs_state || <<>>)}, socket}
  end

  @impl true
  def handle_event("start_edit_title", _params, socket) do
    {:noreply, assign(socket, :editing_title, true)}
  end

  @impl true
  def handle_event("update_title", params, socket) do
    page = socket.assigns.page
    user = socket.assigns.current_scope.user

    # Extract title from either form params or value param (from blur)
    title =
      case params do
        %{"page" => %{"title" => t}} -> t
        %{"value" => t} -> t
        _ -> page.title
      end

    # Only update if title changed
    if String.trim(title) != "" && title != page.title do
      case Pages.update_page(user, page.id, %{title: title}) do
        {:ok, updated_page} ->
          {:noreply,
           socket
           |> assign(:page, updated_page)
           |> assign(:editing_title, false)
           |> assign(:page_form, to_form(%{"title" => updated_page.title}))}

        {:error, _changeset} ->
          {:noreply,
           socket
           |> assign(:editing_title, false)
           |> put_flash(:error, "Failed to update title")}
      end
    else
      {:noreply, assign(socket, :editing_title, false)}
    end
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
  def handle_event("ai_query", %{"question" => question, "node_id" => node_id}, socket) do
    # Spawn async process for streaming AI response
    parent = self()

    spawn_link(fn ->
      params = %{
        question: question,
        node_id: node_id,
        assigns: socket.assigns
      }

      case Documents.ai_query(params, parent) do
        {:ok, query_pid} ->
          # Send PID back to LiveView for tracking
          send(parent, {:ai_query_started, node_id, query_pid})

        {:error, reason} ->
          send(parent, {:ai_error, node_id, reason})
      end
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("ai_cancel", %{"node_id" => node_id}, socket) do
    # Look up the query PID for this node_id
    active_queries = Map.get(socket.assigns, :active_ai_queries, %{})

    case Map.get(active_queries, node_id) do
      nil ->
        # Query not found or already completed
        {:noreply, socket}

      query_pid ->
        # Cancel the query
        Documents.cancel_ai_query(query_pid, node_id)

        # Remove from tracking
        updated_queries = Map.delete(active_queries, node_id)
        {:noreply, assign(socket, :active_ai_queries, updated_queries)}
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

  @impl true
  def handle_info({:ai_query_started, node_id, query_pid}, socket) do
    # Track the query PID for potential cancellation
    active_queries = Map.get(socket.assigns, :active_ai_queries, %{})
    updated_queries = Map.put(active_queries, node_id, query_pid)

    {:noreply, assign(socket, :active_ai_queries, updated_queries)}
  end

  @impl true
  def handle_info({:ai_chunk, node_id, chunk}, socket) do
    # Forward AI chunk to client via push_event
    {:noreply, push_event(socket, "ai_chunk", %{node_id: node_id, chunk: chunk})}
  end

  @impl true
  def handle_info({:ai_done, node_id, response}, socket) do
    # Remove from tracking
    active_queries = Map.get(socket.assigns, :active_ai_queries, %{})
    updated_queries = Map.delete(active_queries, node_id)

    socket =
      socket
      |> assign(:active_ai_queries, updated_queries)
      |> push_event("ai_done", %{node_id: node_id, response: response})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:ai_error, node_id, reason}, socket) do
    # Remove from tracking
    active_queries = Map.get(socket.assigns, :active_ai_queries, %{})
    updated_queries = Map.delete(active_queries, node_id)

    # Forward AI error to client
    error_message = if is_binary(reason), do: reason, else: inspect(reason)

    socket =
      socket
      |> assign(:active_ai_queries, updated_queries)
      |> push_event("ai_error", %{node_id: node_id, error: error_message})

    {:noreply, socket}
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

  defp format_user_name(user) do
    # Format user name as "FirstName L."
    first_name = user.first_name || ""
    last_initial = if user.last_name, do: String.first(user.last_name) <> ".", else: ""
    String.trim("#{first_name} #{last_initial}")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_scope={@current_scope}
      page={@page}
      note={@note}
      workspace={@workspace}
      project={@project}
      page_title={@page.title}
    >
      <div class="flex flex-col">
        <!-- Action Menu (hidden for guests) -->
        <%= if not @readonly do %>
          <div class="flex items-center justify-end flex-shrink-0 mb-4">
            <.kebab_menu button_class="btn-sm">
              <:item
                icon={if @page.is_public, do: "hero-globe-alt", else: "hero-lock-closed"}
                variant={if @page.is_public, do: "info", else: nil}
                phx_click="toggle_public"
              >
                {if @page.is_public, do: "Make Private", else: "Make Public"}
              </:item>
              <:item
                icon={if @page.is_pinned, do: "lucide-pin-off", else: "lucide-pin"}
                variant={if @page.is_pinned, do: "warning", else: nil}
                phx_click="toggle_pin"
              >
                {if @page.is_pinned, do: "Unpin Page", else: "Pin Page"}
              </:item>
              <:item
                icon="hero-trash"
                variant="error"
                phx_click="delete_page"
                data_confirm="Are you sure you want to delete this page?"
              >
                Delete Page
              </:item>
            </.kebab_menu>
          </div>
        <% end %>
        
    <!-- Title Section -->
        <div class="pb-4 mb-4 flex-shrink-0">
          <%= if @editing_title do %>
            <input
              id="page-title-input"
              phx-hook="PageTitleInput"
              type="text"
              name="page[title]"
              value={@page_form[:title].value}
              phx-blur="update_title"
              phx-value-title={@page_form[:title].value}
              class="w-full text-[2em] font-bold leading-tight m-0 input input-bordered focus:input-primary"
              autofocus
            />
          <% else %>
            <h1
              class={[
                "text-[2em] font-bold leading-tight m-0",
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
        <div class="flex-1 flex flex-col overflow-hidden">
          <%= if @readonly do %>
            <div class="alert alert-info mb-4 flex-shrink-0">
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
            data-user-name={format_user_name(@current_scope.user)}
            class={[
              "flex-1 min-h-screen cursor-text",
              if(@readonly, do: "bg-base-100 opacity-90", else: "")
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

  # Chat panel streaming messages
  handle_chat_messages()
end
