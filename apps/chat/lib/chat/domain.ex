defmodule Chat.Domain do
  @moduledoc """
  Domain layer boundary for the Chat context.
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Entities.Session,
      Entities.Message,
      Events.ChatSessionStarted,
      Events.ChatMessageSent,
      Events.ChatSessionDeleted,
      Policies.ReferenceValidationPolicy
    ]
end
