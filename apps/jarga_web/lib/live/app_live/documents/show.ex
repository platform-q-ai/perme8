defmodule JargaWeb.AppLive.Documents.Show do
  @moduledoc """
  LiveView for displaying and editing document content with collaborative notes.
  """

  use JargaWeb, :live_view

  import JargaWeb.ChatLive.MessageHandlers

  alias Jarga.{Documents, Notes, Workspaces, Projects}

  @impl true
  def mount(
        %{"workspace_slug" => workspace_slug, "document_slug" => document_slug},
        _session,
        socket
      ) do
    user = socket.assigns.current_scope.user

    # Optimized: get workspace and member in single query
    with {:ok, workspace, member} <-
           Workspaces.get_workspace_and_member_by_slug(user, workspace_slug),
         {:ok, document} <- get_document_by_slug(user, workspace.id, document_slug),
         {:ok, project} <- get_project_if_exists(user, document) do
      # Get the note component (first note in document_components)
      note = Documents.get_document_note(document)

      # Subscribe to document updates via PubSub for collaborative editing
      if connected?(socket) do
        Phoenix.PubSub.subscribe(Jarga.PubSub, "document:#{document.id}")
        Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")
      end

      # Generate user ID for collaborative editing
      collab_user_id = generate_user_id()

      # Determine if the editor should be read-only (guests can only view)
      readonly = member.role == :guest

      {:ok,
       socket
       |> assign(:document, document)
       |> assign(:note, note)
       |> assign(:workspace, workspace)
       |> assign(:project, project)
       |> assign(:current_member, member)
       |> assign(:user_id, collab_user_id)
       |> assign(:editing_title, false)
       |> assign(:readonly, readonly)
       |> assign(:document_form, to_form(%{"title" => document.title}))}
    else
      {:error, _reason} ->
        {:ok,
         socket
         |> put_flash(:error, "Document not found")
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
    document = socket.assigns.document
    note = socket.assigns.note
    current_user = socket.assigns.current_scope.user

    # 1. IMMEDIATELY broadcast the incremental update to other clients
    Phoenix.PubSub.broadcast_from(
      Jarga.PubSub,
      self(),
      "document:#{document.id}",
      {:yjs_update, %{update: update, user_id: user_id}}
    )

    # 2. Send to debouncer for eventual database save (server-side debouncing)
    complete_state_binary = Base.decode64!(complete_state)

    JargaWeb.DocumentSaveDebouncer.request_save(
      document.id,
      current_user,
      note.id,
      complete_state_binary,
      markdown
    )

    # 3. Update socket assigns with latest state so get_current_yjs_state returns fresh data
    # This prevents false "out of sync" warnings before the debouncer saves to DB
    updated_note = %{
      note
      | yjs_state: complete_state_binary,
        note_content: markdown
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
      note_content: markdown
    }

    case Notes.update_note_via_document(current_user, note.id, update_attrs) do
      {:ok, updated_note} ->
        {:noreply, assign(socket, :note, updated_note)}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("awareness_update", %{"update" => update, "user_id" => user_id}, socket) do
    document = socket.assigns.document

    # Broadcast awareness updates to other clients
    Phoenix.PubSub.broadcast_from(
      Jarga.PubSub,
      self(),
      "document:#{document.id}",
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
    document = socket.assigns.document
    user = socket.assigns.current_scope.user

    # Extract title from either form params or value param (from blur)
    title =
      case params do
        %{"document" => %{"title" => t}} -> t
        %{"value" => t} -> t
        _ -> document.title
      end

    # Only update if title changed
    if String.trim(title) != "" && title != document.title do
      case Documents.update_document(user, document.id, %{title: title}) do
        {:ok, updated_document} ->
          {:noreply,
           socket
           |> assign(:document, updated_document)
           |> assign(:editing_title, false)
           |> assign(:document_form, to_form(%{"title" => updated_document.title}))}

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
  def handle_event("handle_title_key", %{"key" => "Enter"}, socket) do
    # Blur will trigger update_title, then focus editor
    # Use JS.dispatch to send event to editor after short delay
    {:noreply, push_event(socket, "focus-editor", %{})}
  end

  def handle_event("handle_title_key", %{"key" => "Escape"}, socket) do
    # Cancel editing without saving changes
    {:noreply, assign(socket, :editing_title, false)}
  end

  def handle_event("handle_title_key", _params, socket) do
    # Ignore other keys
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_pin", _params, socket) do
    document = socket.assigns.document
    user = socket.assigns.current_scope.user

    case Documents.update_document(user, document.id, %{is_pinned: !document.is_pinned}) do
      {:ok, updated_document} ->
        {:noreply,
         socket
         |> assign(:document, updated_document)
         |> put_flash(
           :info,
           if(updated_document.is_pinned, do: "Document pinned", else: "Document unpinned")
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update pin status")}
    end
  end

  @impl true
  def handle_event("toggle_public", _params, socket) do
    document = socket.assigns.document
    user = socket.assigns.current_scope.user

    case Documents.update_document(user, document.id, %{is_public: !document.is_public}) do
      {:ok, updated_document} ->
        {:noreply,
         socket
         |> assign(:document, updated_document)
         |> put_flash(
           :info,
           if(updated_document.is_public,
             do: "Document is now shared with workspace members",
             else: "Document is now private"
           )
         )}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to update sharing status")}
    end
  end

  @impl true
  def handle_event("delete_document", _params, socket) do
    document = socket.assigns.document
    workspace = socket.assigns.workspace
    user = socket.assigns.current_scope.user

    case Documents.delete_document(user, document.id) do
      {:ok, _deleted_document} ->
        {:noreply,
         socket
         |> put_flash(:info, "Document deleted")
         |> push_navigate(to: ~p"/app/workspaces/#{workspace.slug}")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to delete document")}
    end
  end

  @impl true
  def handle_event("agent_query", %{"question" => question, "node_id" => node_id}, socket) do
    # Spawn async process for streaming agent response
    parent = self()

    spawn_link(fn ->
      params = %{
        question: question,
        node_id: node_id,
        assigns: socket.assigns
      }

      case Agents.agent_query(params, parent) do
        {:ok, query_pid} ->
          # Send PID back to LiveView for tracking
          send(parent, {:agent_query_started, node_id, query_pid})

        {:error, reason} ->
          send(parent, {:ai_error, node_id, reason})
      end
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_event("agent_query_command", %{"command" => command, "node_id" => node_id}, socket) do
    user = socket.assigns.current_scope.user
    workspace = socket.assigns.workspace

    # Delegate to Documents context to parse command and execute agent query
    params = %{
      command: command,
      user: user,
      workspace_id: workspace.id,
      assigns: socket.assigns,
      node_id: node_id
    }

    case Documents.execute_agent_query(params, self()) do
      {:ok, query_pid} ->
        # Track the query PID
        send(self(), {:agent_query_started, node_id, query_pid})
        {:noreply, socket}

      {:error, reason} ->
        error_msg = format_agent_error(reason)
        send(self(), {:agent_error, node_id, error_msg})
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("agent_cancel", %{"node_id" => node_id}, socket) do
    # Look up the query PID for this node_id
    active_queries = Map.get(socket.assigns, :active_agent_queries, %{})

    case Map.get(active_queries, node_id) do
      nil ->
        # Query not found or already completed
        {:noreply, socket}

      query_pid ->
        # Cancel the query
        Agents.cancel_agent_query(query_pid, node_id)

        # Remove from tracking
        updated_queries = Map.delete(active_queries, node_id)
        {:noreply, assign(socket, :active_agent_queries, updated_queries)}
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
  def handle_info({:document_visibility_changed, document_id, is_public}, socket) do
    # Update document visibility in real-time when changed by another user
    if socket.assigns.document.id == document_id do
      document = %{socket.assigns.document | is_public: is_public}
      {:noreply, assign(socket, :document, document)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:document_pinned_changed, document_id, is_pinned}, socket) do
    # Update document pinned state in real-time when changed by another user
    if socket.assigns.document.id == document_id do
      document = %{socket.assigns.document | is_pinned: is_pinned}
      {:noreply, assign(socket, :document, document)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:document_title_changed, document_id, title}, socket) do
    # Update document title in the document show view (from another user's edit)
    if socket.assigns.document.id == document_id do
      document = %{socket.assigns.document | title: title}
      document_form = to_form(%{"title" => title})
      {:noreply, socket |> assign(:document, document) |> assign(:document_form, document_form)}
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
  def handle_info({:agent_query_started, node_id, query_pid}, socket) do
    # Track the query PID for potential cancellation
    active_queries = Map.get(socket.assigns, :active_agent_queries, %{})
    updated_queries = Map.put(active_queries, node_id, query_pid)

    {:noreply, assign(socket, :active_agent_queries, updated_queries)}
  end

  @impl true
  def handle_info({:agent_chunk, node_id, chunk}, socket) do
    # Forward agent chunk to client via push_event
    {:noreply, push_event(socket, "agent_chunk", %{node_id: node_id, chunk: chunk})}
  end

  @impl true
  def handle_info({:agent_done, node_id, response}, socket) do
    # Remove from tracking
    active_queries = Map.get(socket.assigns, :active_agent_queries, %{})
    updated_queries = Map.delete(active_queries, node_id)

    socket =
      socket
      |> assign(:active_agent_queries, updated_queries)
      |> push_event("agent_done", %{node_id: node_id, response: response})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:agent_error, node_id, reason}, socket) do
    # Remove from tracking
    active_queries = Map.get(socket.assigns, :active_agent_queries, %{})
    updated_queries = Map.delete(active_queries, node_id)

    # Forward agent error to client
    error_message = if is_binary(reason), do: reason, else: inspect(reason)

    socket =
      socket
      |> assign(:active_agent_queries, updated_queries)
      |> push_event("agent_error", %{node_id: node_id, error: error_message})

    {:noreply, socket}
  end

  @impl true
  def handle_info({:workspace_agent_updated, _agent}, socket) do
    # Reload workspace agents and send to chat panel
    workspace_id = socket.assigns.workspace.id
    user = socket.assigns.current_scope.user

    agents = Agents.get_workspace_agents_list(workspace_id, user.id, enabled_only: true)

    send_update(JargaWeb.ChatLive.Panel,
      id: "global-chat-panel",
      workspace_agents: agents,
      from_pubsub: true
    )

    {:noreply, socket}
  end

  @impl true
  def handle_info({:document_created, _document}, socket) do
    # Document created broadcasts - no action needed on document show page
    {:noreply, socket}
  end

  defp generate_user_id do
    "user_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"
  end

  defp get_initial_markdown(note) do
    # note_content is now plain text markdown
    case note.note_content do
      content when is_binary(content) -> content
      _ -> ""
    end
  end

  defp format_user_name(user) do
    # Format user name as "FirstName L."
    first_name = user.first_name || ""
    last_initial = if user.last_name, do: String.first(user.last_name) <> ".", else: ""
    String.trim("#{first_name} #{last_initial}")
  end

  # Format agent query error messages for display to user
  defp format_agent_error(:invalid_command_format),
    do: "Invalid command format. Use: @j agent_name Question"

  defp format_agent_error(:agent_not_found), do: "Agent not found in workspace"
  defp format_agent_error(:agent_disabled), do: "Agent is disabled"
  defp format_agent_error(reason) when is_binary(reason), do: reason
  defp format_agent_error(_reason), do: "Failed to execute agent query"

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.admin
      flash={@flash}
      current_scope={@current_scope}
      document={@document}
      note={@note}
      workspace={@workspace}
      project={@project}
      document_title={@document.title}
    >
      <div class="flex flex-col">
        <!-- Action Menu (hidden for guests) -->
        <%= if not @readonly do %>
          <div class="flex items-center justify-end flex-shrink-0 mb-4">
            <.kebab_menu button_class="btn-sm">
              <:item
                icon={if @document.is_public, do: "hero-globe-alt", else: "hero-lock-closed"}
                variant={if @document.is_public, do: "info", else: nil}
                phx_click="toggle_public"
              >
                {if @document.is_public, do: "Make Private", else: "Make Public"}
              </:item>
              <:item
                icon={if @document.is_pinned, do: "lucide-pin-off", else: "lucide-pin"}
                variant={if @document.is_pinned, do: "warning", else: nil}
                phx_click="toggle_pin"
              >
                {if @document.is_pinned, do: "Unpin Document", else: "Pin Document"}
              </:item>
              <:item
                icon="hero-trash"
                variant="error"
                phx_click="delete_document"
                data_confirm="Are you sure you want to delete this document?"
              >
                Delete Document
              </:item>
            </.kebab_menu>
          </div>
        <% end %>
        
    <!-- Title Section -->
        <div class="pb-4 mb-4 flex-shrink-0">
          <%= if @editing_title do %>
            <input
              id="document-title-input"
              type="text"
              name="document[title]"
              value={@document_form[:title].value}
              phx-blur="update_title"
              phx-keydown="handle_title_key"
              phx-value-title={@document_form[:title].value}
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
              {@document.title}
            </h1>
          <% end %>
        </div>
        
    <!-- Editor -->
        <div class="flex-1 flex flex-col overflow-hidden">
          <%= if @readonly do %>
            <div class="alert alert-info mb-4 flex-shrink-0">
              <.icon name="hero-eye" class="size-5" />
              <span>You are viewing this document in read-only mode.</span>
            </div>
          <% end %>
          <div
            id="editor-container"
            phx-hook="MilkdownEditor"
            phx-update="ignore"
            data-yjs-state={if @note.yjs_state, do: Base.encode64(@note.yjs_state), else: ""}
            data-initial-content={get_initial_markdown(@note)}
            data-readonly={if @readonly, do: "true", else: "false"}
            data-user-id={@user_id}
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

  defp get_document_by_slug(user, workspace_id, slug) do
    Documents.get_document_by_slug(user, workspace_id, slug)
  end

  defp get_project_if_exists(user, document) do
    if document.project_id do
      case Projects.get_project(user, document.workspace_id, document.project_id) do
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
