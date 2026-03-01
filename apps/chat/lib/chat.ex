defmodule Chat do
  @moduledoc """
  Public facade for the Chat bounded context.
  """

  use Boundary,
    top_level?: true,
    deps: [Chat.Domain, Chat.Application, Chat.Infrastructure, Chat.Repo],
    exports: [
      {Domain.Entities.Session, []},
      {Domain.Entities.Message, []},
      {Domain.Events.ChatSessionStarted, []},
      {Domain.Events.ChatMessageSent, []},
      {Domain.Events.ChatSessionDeleted, []}
    ]

  alias Chat.Application.UseCases.{
    CreateSession,
    DeleteMessage,
    DeleteSession,
    ListSessions,
    LoadSession,
    PrepareContext,
    SaveMessage
  }

  defdelegate prepare_chat_context(context_map), to: PrepareContext, as: :execute
  defdelegate build_system_message(context), to: PrepareContext
  defdelegate build_system_message_with_agent(agent, context), to: PrepareContext

  defdelegate create_session(attrs), to: CreateSession, as: :execute
  defdelegate list_sessions(user_id, opts \\ []), to: ListSessions, as: :execute
  defdelegate load_session(session_id), to: LoadSession, as: :execute
  defdelegate delete_session(session_id, user_id), to: DeleteSession, as: :execute

  defdelegate save_message(attrs), to: SaveMessage, as: :execute
  defdelegate delete_message(message_id, user_id), to: DeleteMessage, as: :execute
end
