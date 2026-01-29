defmodule Jarga.Projects.Domain do
  @moduledoc """
  Domain layer boundary for the Projects context.

  Contains pure business logic with no external dependencies:

  ## Entities
  - `Entities.Project` - Project domain entity

  ## Services (Pure Functions)
  - `SlugGenerator` - Project slug generation

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
      Entities.Project,
      SlugGenerator
    ]
end
