defmodule JargaWeb.EditorLive do
  use JargaWeb, :live_view

  @impl true
  def mount(%{"doc_id" => doc_id}, _session, socket) do
    user_id = generate_user_id()

    if connected?(socket) do
      Phoenix.PubSub.subscribe(Jarga.PubSub, "document:#{doc_id}")
    end

    {:ok,
     socket
     |> assign(:doc_id, doc_id)
     |> assign(:content, get_document(doc_id))
     |> assign(:user_id, user_id)}
  end

  @impl true
  def mount(_params, _session, socket) do
    # Default to a random document ID
    doc_id = "doc_#{:rand.uniform(10000)}"
    {:ok, push_navigate(socket, to: ~p"/editor/#{doc_id}")}
  end

  @impl true
  def handle_event("yjs_update", %{"update" => update, "user_id" => user_id}, socket) do
    doc_id = socket.assigns.doc_id

    # Store the Yjs update
    store_yjs_update(doc_id, update)

    # Broadcast to other clients
    Phoenix.PubSub.broadcast_from(
      Jarga.PubSub,
      self(),
      "document:#{doc_id}",
      {:yjs_update, %{update: update, user_id: user_id}}
    )

    {:noreply, socket}
  end

  @impl true
  def handle_event("awareness_update", %{"update" => update, "user_id" => user_id}, socket) do
    doc_id = socket.assigns.doc_id

    # Broadcast awareness updates to other clients
    Phoenix.PubSub.broadcast_from(
      Jarga.PubSub,
      self(),
      "document:#{doc_id}",
      {:awareness_update, %{update: update, user_id: user_id}}
    )

    {:noreply, socket}
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

  # Storage functions
  defp get_document(doc_id) do
    case :persistent_term.get({:doc, doc_id}, nil) do
      nil ->
        content = "# Welcome to Collaborative Markdown Editor\n\nStart typing..."
        :persistent_term.put({:doc, doc_id}, content)
        :persistent_term.put({:yjs_updates, doc_id}, [])
        content

      content ->
        content
    end
  end

  defp store_yjs_update(doc_id, update) do
    # Store the Yjs update for new clients
    # Keep last 100 updates for memory efficiency
    current_updates = :persistent_term.get({:yjs_updates, doc_id}, [])
    all_updates = (current_updates ++ [update]) |> Enum.take(-100)
    :persistent_term.put({:yjs_updates, doc_id}, all_updates)
  end

  defp generate_user_id do
    "user_#{:crypto.strong_rand_bytes(8) |> Base.encode16()}"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col">
      <div class="bg-gray-800 text-white p-4">
        <h1 class="text-2xl font-bold">Collaborative Markdown Editor (WYSIWYG + Yjs)</h1>
        <p class="text-sm text-gray-300">
          Document ID: <%= @doc_id %> | User ID: <%= @user_id %>
        </p>
      </div>

      <div class="flex-1 p-4">
        <div
          id="editor-container"
          phx-hook="MilkdownEditor"
          phx-update="ignore"
          data-content={@content}
          class="border border-gray-300 rounded-lg h-full"
        >
        </div>
      </div>
    </div>
    """
  end
end
