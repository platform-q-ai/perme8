defmodule JargaWeb.ChatLive.Components.Message do
  @moduledoc """
  Message component for displaying chat messages.
  """
  use Phoenix.Component
  import JargaWeb.CoreComponents

  attr :message, :map, required: true

  def message(assigns) do
    ~H"""
    <div class={"chat-message #{@message.role}"} data-role={@message.role}>
      <div class="message-avatar">
        <%= if @message.role == "user" do %>
          <.icon name="hero-user-circle" class="w-6 h-6" />
        <% else %>
          <.icon name="hero-sparkles" class="w-6 h-6" />
        <% end %>
      </div>
      <div class="message-content">
        <div class="message-text">
          <%= @message.content %>
          <%= if Map.get(@message, :streaming, false) do %>
            <span class="streaming-cursor">▊</span>
          <% end %>
        </div>
        <%= if !Map.get(@message, :streaming, false) do %>
          <div class="message-timestamp">
            <%= format_timestamp(@message.timestamp) %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  defp format_timestamp(timestamp) do
    now = DateTime.utc_now()
    diff_seconds = DateTime.diff(now, timestamp, :second)

    cond do
      diff_seconds < 60 -> "just now"
      diff_seconds < 3600 -> "#{div(diff_seconds, 60)}m ago"
      diff_seconds < 86400 -> "#{div(diff_seconds, 3600)}h ago"
      true -> Calendar.strftime(timestamp, "%b %d, %I:%M %p")
    end
  end
end
