defmodule Alkali.InfrastructureLayer do
  @moduledoc """
  Infrastructure layer namespace for the Alkali static site generator.

  The infrastructure layer contains:

  - **Services** - External concern implementations
    - `FileSystem` - File system operations
    - `BuildCache` - Incremental build caching
    - `ConfigLoader` - Site configuration loading
    - `CryptoService` - Cryptographic operations (hashing)
    - `LayoutResolver` - Layout template resolution

  - **Parsers** (`Alkali.Infrastructure.Parsers.*`)
    - `FrontmatterParser` - YAML frontmatter parsing
    - `MarkdownParser` - Markdown to HTML conversion

  - **Renderers** (`Alkali.Infrastructure.Renderers.*`)
    - `TemplateRenderer` - EEx template rendering
    - `CollectionRenderer` - Collection page HTML generation
    - `RssRenderer` - RSS feed XML generation

  ## Boundary Rules

  The infrastructure layer:
  - Implements behaviours defined in the application layer
  - May depend on domain entities for data structures
  - May use external libraries (Jason, EEx, etc.)

  The infrastructure layer is injected into use cases via options,
  following the Dependency Inversion Principle.
  """

  use Boundary,
    deps: [Alkali.Domain, Alkali.ApplicationLayer],
    exports: [
      FileSystem,
      BuildCache,
      ConfigLoader,
      CryptoService,
      LayoutResolver,
      Parsers.FrontmatterParser,
      Parsers.MarkdownParser,
      Renderers.TemplateRenderer,
      Renderers.CollectionRenderer,
      Renderers.RssRenderer
    ]
end
