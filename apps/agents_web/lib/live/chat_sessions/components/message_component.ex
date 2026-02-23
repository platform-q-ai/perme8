defmodule AgentsWeb.ChatSessionsLive.Components.MessageComponent do
  @moduledoc """
  Read-only message component for displaying chat messages.

  Renders user and assistant messages with appropriate styling.
  Assistant messages are rendered with markdown via MDEx.
  User messages are rendered as plain text.

  This is a simplified, read-only version of the chat message component
  used in the chat sessions dashboard view.
  """

  use Phoenix.Component

  attr(:message, :map, required: true)

  def message(assigns) do
    assigns = assign(assigns, :rendered_content, render_content(assigns.message))

    ~H"""
    <div
      class={"chat #{if @message.role == "user", do: "chat-end", else: "chat-start"}"}
      data-message-role={@message.role}
      data-message-content={truncate_for_attribute(@message.content)}
    >
      <div class="chat-header opacity-50 text-xs" data-message-role-label>
        {@message.role}
      </div>

      <div class={"chat-bubble text-sm #{if @message.role == "user", do: "chat-bubble-primary", else: ""}"}>
        <%= if @message.role == "assistant" do %>
          <div class="chat-markdown">
            {Phoenix.HTML.raw(@rendered_content)}
          </div>
        <% else %>
          {@message.content}
        <% end %>
      </div>

      <div class="chat-footer opacity-50 text-xs" data-message-timestamp>
        {format_timestamp(@message.inserted_at)}
      </div>
    </div>
    """
  end

  # Truncate content for data attributes to avoid bloated HTML.
  # BDD tests only check attribute presence/visibility, not the full value.
  @attribute_max_length 200

  defp truncate_for_attribute(nil), do: nil

  defp truncate_for_attribute(content) when byte_size(content) > @attribute_max_length do
    String.slice(content, 0, @attribute_max_length)
  end

  defp truncate_for_attribute(content), do: content

  defp render_content(%{role: "assistant", content: content}) do
    opts = [
      extension: [
        strikethrough: true,
        table: true,
        tasklist: true,
        autolink: true
      ]
    ]

    case MDEx.to_html(content, opts) do
      {:ok, html} -> html
      {:error, _} -> content
    end
  end

  defp render_content(%{content: content}), do: content

  defp format_timestamp(%DateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %I:%M %p")
  end

  defp format_timestamp(_), do: ""
end
