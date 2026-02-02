defmodule Jarga.Chat.Application do
  @moduledoc """
  Application layer boundary for the Chat context.

  Contains orchestration logic that coordinates domain and infrastructure:

  ## Use Cases
  - `UseCases.PrepareContext` - Prepare chat context from LiveView assigns
  - `UseCases.CreateSession` - Create new chat session
  - `UseCases.SaveMessage` - Save message to chat session
  - `UseCases.DeleteMessage` - Delete message from chat session
  - `UseCases.LoadSession` - Load session with messages
  - `UseCases.ListSessions` - List user's chat sessions
  - `UseCases.DeleteSession` - Delete chat session

  ## Dependency Rule

  The Application layer may only depend on:
  - Domain layer (same context)

  It cannot import:
  - Infrastructure layer (repos, schemas)
  - Other contexts directly (use dependency injection)
  """

  use Boundary,
    top_level?: true,
    deps: [Jarga.Chat.Domain],
    exports: [
      UseCases.PrepareContext,
      UseCases.CreateSession,
      UseCases.SaveMessage,
      UseCases.DeleteMessage,
      UseCases.LoadSession,
      UseCases.ListSessions,
      UseCases.DeleteSession,
      # Behaviours (interfaces for Infrastructure to implement)
      Behaviours.MessageRepositoryBehaviour,
      Behaviours.SessionRepositoryBehaviour
    ]
end
