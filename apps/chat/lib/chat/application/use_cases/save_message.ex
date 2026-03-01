defmodule Chat.Application.UseCases.SaveMessage do
  @moduledoc """
  Saves a chat message to a session.
  """

  alias Chat.Domain.Events.ChatMessageSent

  @default_message_repository Chat.Infrastructure.Repositories.MessageRepository
  @default_session_repository Chat.Infrastructure.Repositories.SessionRepository
  @default_event_bus Perme8.Events.EventBus

  def execute(attrs, opts \\ []) do
    message_repository = Keyword.get(opts, :message_repository, @default_message_repository)
    session_repository = Keyword.get(opts, :session_repository, @default_session_repository)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    event_bus_opts = Keyword.get(opts, :event_bus_opts, [])

    case message_repository.create_message(attrs) do
      {:ok, message} ->
        emit_message_sent_event(message, session_repository, event_bus, event_bus_opts)
        {:ok, message}

      error ->
        error
    end
  end

  defp emit_message_sent_event(message, session_repository, event_bus, event_bus_opts) do
    session = session_repository.get_session_by_id(message.chat_session_id)

    if session do
      event =
        ChatMessageSent.new(%{
          aggregate_id: message.id,
          actor_id: session.user_id,
          message_id: message.id,
          session_id: message.chat_session_id,
          user_id: session.user_id,
          role: message.role,
          workspace_id: session.workspace_id
        })

      event_bus.emit(event, event_bus_opts)
    end
  end
end
