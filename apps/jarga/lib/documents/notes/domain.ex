defmodule Jarga.Documents.Notes.Domain do
  @moduledoc """
  Domain layer boundary for the Notes subdomain within Documents context.

  Contains pure business logic with no external dependencies:

  ## Entities
  - `Entities.Note` - Note domain entity

  ## Dependency Rule

  The Domain layer has NO dependencies. It cannot import:
  - Application layer (use cases, services)
  - Infrastructure layer (repos, schemas, notifiers)
  - External libraries (Ecto, Phoenix, etc.)
  - Other contexts
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Entities.Note,
      ContentHash
    ]
end
