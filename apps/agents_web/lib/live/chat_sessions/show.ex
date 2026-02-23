defmodule AgentsWeb.ChatSessionsLive.Show do
  @moduledoc """
  LiveView for displaying a single chat session with its messages.

  Loads a session by ID and renders all messages in chronological order
  using the message component. Provides navigation back to the sessions list.

  This is a standalone view that can be mounted in agents_web directly
  or embedded in the Perme8 Dashboard.
  """

  use AgentsWeb, :live_view

  alias AgentsWeb.ChatSessionsLive.Components.MessageComponent

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    case Jarga.Chat.load_session(id) do
      {:ok, session} ->
        title = session.title || "Untitled Session"

        {:noreply,
         socket
         |> assign(:page_title, title)
         |> assign(:session, session)
         |> assign(:display_title, title)}

      {:error, :not_found} ->
        {:noreply,
         socket
         |> put_flash(:error, "Session not found")
         |> redirect(to: ~p"/chat-sessions")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div data-session-detail class="space-y-6">
      <div class="flex items-center gap-4">
        <.link navigate={~p"/chat-sessions"} class="btn btn-ghost btn-sm">
          <.icon name="hero-arrow-left" class="size-4" /> Back
        </.link>
        <h1 class="text-2xl font-bold" data-session-title>{@display_title}</h1>
      </div>

      <div class="space-y-4">
        <%= for message <- @session.messages do %>
          <div data-session-message>
            <MessageComponent.message message={message_assigns(message)} />
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp message_assigns(message) do
    %{
      role: message.role,
      content: message.content,
      inserted_at: message.inserted_at
    }
  end
end
