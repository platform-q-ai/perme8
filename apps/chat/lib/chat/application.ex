defmodule Chat.Application do
  @moduledoc """
  Application layer boundary for the Chat context.
  """

  use Boundary,
    top_level?: true,
    deps: [Chat.Domain, Perme8.Events],
    exports: [
      UseCases.PrepareContext,
      UseCases.CreateSession,
      UseCases.SaveMessage,
      UseCases.DeleteMessage,
      UseCases.LoadSession,
      UseCases.ListSessions,
      UseCases.DeleteSession,
      Behaviours.MessageRepositoryBehaviour,
      Behaviours.SessionRepositoryBehaviour,
      Behaviours.IdentityApiBehaviour
    ]
end
