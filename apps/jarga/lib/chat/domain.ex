defmodule Jarga.Chat.Domain do
  @moduledoc """
  Domain layer boundary for the Chat context.

  Contains pure business logic with NO external dependencies:

  ## Entities
  - `Entities.Session` - Chat session domain entity (pure struct)
  - `Entities.Message` - Chat message domain entity (pure struct)

  ## Dependency Rule

  The Domain layer has NO dependencies. It cannot import:
  - Application layer (use cases)
  - Infrastructure layer (repos, schemas)
  - External libraries (Ecto, Phoenix, etc.)
  - Other contexts
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Entities.Session,
      Entities.Message
    ]
end
