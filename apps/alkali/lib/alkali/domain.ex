defmodule Alkali.Domain do
  @moduledoc """
  Domain layer namespace for the Alkali static site generator.

  The domain layer contains:

  - **Entities** (`Alkali.Domain.Entities.*`) - Core business objects
    - `Asset` - Represents static assets (CSS, JS, images)
    - `Collection` - Groups of pages (tags, categories, posts)
    - `Page` - Represents a content page
    - `Site` - Site configuration and metadata

  - **Policies** (`Alkali.Domain.Policies.*`) - Business rules
    - `FrontmatterPolicy` - Validates and processes frontmatter
    - `SlugPolicy` - Generates URL-safe slugs
    - `UrlPolicy` - Generates URLs from content

  ## Boundary Rules

  The domain layer has NO external dependencies. It only depends on:
  - Elixir standard library
  - Erlang standard library

  Other layers may depend on the domain, but the domain NEVER depends on:
  - Application layer (use cases, behaviours)
  - Infrastructure layer (file system, parsers, renderers)
  - External libraries
  """

  # Domain boundary is enforced by Alkali top-level boundary
  # Dependency rules:
  # - Domain has NO external dependencies
  # - Domain is depended upon by Application and Infrastructure layers
end
