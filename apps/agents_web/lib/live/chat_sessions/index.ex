defmodule AgentsWeb.ChatSessionsLive.Index do
  @moduledoc """
  LiveView for listing and managing all chat sessions.

  Displays a table of chat sessions with title, message count, and timestamp.
  Sessions can be clicked to view their messages or deleted.

  This is a standalone view that can be mounted in agents_web directly
  or embedded in the Perme8 Dashboard.
  """

  use AgentsWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, sessions} = Jarga.Chat.list_all_sessions(limit: 50)

    {:ok,
     socket
     |> assign(:page_title, "Chat Sessions")
     |> assign(:session_count, length(sessions))
     |> stream(:sessions, sessions)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete_session", %{"id" => session_id}, socket) do
    case Jarga.Chat.load_session(session_id) do
      {:ok, session} ->
        case Jarga.Chat.delete_session(session_id, session.user_id) do
          {:ok, _deleted} ->
            {:noreply,
             socket
             |> stream_delete_by_dom_id(:sessions, "sessions-#{session_id}")
             |> update(:session_count, &max(&1 - 1, 0))
             |> put_flash(:info, "Session deleted")}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to delete session")}
        end

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Session not found")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.header>
        Chat Sessions
        <:subtitle>Browse all chat conversations</:subtitle>
      </.header>

      <%= if @session_count == 0 do %>
        <div data-empty-state class="card bg-base-200">
          <div class="card-body text-center">
            <div class="flex flex-col items-center gap-4 py-8">
              <.icon name="hero-chat-bubble-left-right" class="size-16 opacity-50" />
              <div>
                <h3 class="text-base font-semibold">No chat sessions yet</h3>
                <p class="text-base-content/70">
                  Chat sessions will appear here once conversations are started.
                </p>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <div data-session-list>
        <div class="card bg-base-200">
          <div class="card-body p-0">
            <table class="table table-zebra">
              <thead>
                <tr>
                  <th class="text-sm font-semibold">Title</th>
                  <th class="text-sm font-semibold">Messages</th>
                  <th class="text-sm font-semibold">Last Updated</th>
                  <th class="text-sm font-semibold w-10"></th>
                </tr>
              </thead>
              <tbody id="sessions" phx-update="stream">
                <tr
                  :for={{dom_id, session} <- @streams.sessions}
                  id={dom_id}
                  data-session={session.id}
                >
                  <td data-session-title>
                    <.link navigate={~p"/chat-sessions/#{session.id}"} class="link link-hover">
                      {session.title || "Untitled Session"}
                    </.link>
                  </td>
                  <td data-session-message-count>
                    {session.message_count}
                  </td>
                  <td data-session-timestamp>
                    {format_relative_time(session.updated_at)}
                  </td>
                  <td>
                    <button
                      type="button"
                      phx-click="delete_session"
                      phx-value-id={session.id}
                      data-session-delete
                      data-confirm="Delete this chat session?"
                      class="btn btn-ghost btn-xs"
                      title="Delete"
                    >
                      <.icon
                        name="hero-trash"
                        class="size-4 text-base-content/40 hover:text-error"
                      />
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
    """
  end

  defp format_relative_time(%DateTime{} = dt) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, dt, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86_400 -> "#{div(diff_seconds, 3600)}h ago"
      true -> Calendar.strftime(dt, "%b %d, %Y")
    end
  end

  defp format_relative_time(%NaiveDateTime{} = ndt) do
    ndt
    |> DateTime.from_naive!("Etc/UTC")
    |> format_relative_time()
  end

  defp format_relative_time(_), do: ""
end
