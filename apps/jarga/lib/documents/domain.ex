defmodule Jarga.Documents.Domain do
  @moduledoc """
  Domain layer boundary for the Documents context.

  Contains pure business logic with no external dependencies:

  ## Entities
  - `Entities.Document` - Document domain entity
  - `Entities.DocumentComponent` - Document component domain entity

  ## Policies (Business Rules)
  - `Policies.DocumentAccessPolicy` - Document access rules

  ## Services (Pure Functions)
  - `SlugGenerator` - Document slug generation
  - `AgentQueryParser` - Agent query command parsing

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
      Entities.Document,
      Entities.DocumentComponent,
      Policies.DocumentAccessPolicy,
      SlugGenerator,
      AgentQueryParser,
      Events.DocumentCreated,
      Events.DocumentDeleted,
      Events.DocumentTitleChanged,
      Events.DocumentVisibilityChanged,
      Events.DocumentPinnedChanged
    ]
end
