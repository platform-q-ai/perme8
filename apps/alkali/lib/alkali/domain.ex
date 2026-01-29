defmodule Alkali.Domain do
  @moduledoc """
  Domain layer boundary for the Alkali static site generator.

  Contains pure business logic with NO external dependencies:

  ## Entities (Data Structures)
  - `Entities.Asset` - Asset file representation
  - `Entities.Collection` - Collection of pages (e.g., posts, tags)
  - `Entities.Page` - Content page representation
  - `Entities.Site` - Site configuration and metadata

  ## Policies (Business Rules)
  - `Policies.FrontmatterPolicy` - Frontmatter validation rules
  - `Policies.SlugPolicy` - URL slug generation rules
  - `Policies.UrlPolicy` - URL construction rules

  ## Dependency Rule

  The Domain layer has NO dependencies. It cannot import:
  - Application layer (use cases, services)
  - Infrastructure layer (parsers, renderers, file system)
  - External libraries (File, IO, etc.)
  - Other contexts
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Entities.Asset,
      Entities.Collection,
      Entities.Page,
      Entities.Site,
      Policies.FrontmatterPolicy,
      Policies.SlugPolicy,
      Policies.UrlPolicy
    ]
end
