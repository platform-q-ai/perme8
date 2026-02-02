defmodule Jarga.Workspaces.Domain do
  @moduledoc """
  Domain layer boundary for the Workspaces context.

  Contains pure business logic with no external dependencies:

  ## Entities
  - `Entities.Workspace` - Workspace domain entity
  - `Entities.WorkspaceMember` - Workspace member domain entity

  ## Services (Pure Functions)
  - `SlugGenerator` - Workspace slug generation

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
      Entities.Workspace,
      Entities.WorkspaceMember,
      SlugGenerator
    ]
end
