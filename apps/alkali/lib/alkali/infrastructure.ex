defmodule Alkali.Infrastructure do
  @moduledoc """
  Infrastructure layer boundary for the Alkali static site generator.

  Contains implementations that interact with external systems:

  ## Parsers
  - `Parsers.FrontmatterParser` - YAML frontmatter parsing
  - `Parsers.MarkdownParser` - Markdown to HTML conversion

  ## Renderers
  - `Renderers.CollectionRenderer` - Collection page rendering
  - `Renderers.RssRenderer` - RSS feed rendering
  - `Renderers.TemplateRenderer` - EEx template rendering

  ## Services
  - `BuildCache` - Incremental build caching
  - `ConfigLoader` - Site configuration loading
  - `CryptoService` - Cryptographic operations
  - `FileSystem` - File system operations wrapper
  - `LayoutResolver` - Layout file resolution and rendering

  ## Dependency Rule

  The Infrastructure layer may depend on:
  - Domain layer (for entities and policies)
  - Application layer (to implement service behaviours)

  It can use external libraries (File, IO, YAML, Markdown, etc.)
  """

  use Boundary,
    top_level?: true,
    deps: [
      Alkali.Domain,
      Alkali.Application
    ],
    exports: [
      Parsers.FrontmatterParser,
      Parsers.MarkdownParser,
      Renderers.CollectionRenderer,
      Renderers.RssRenderer,
      Renderers.TemplateRenderer,
      BuildCache,
      ConfigLoader,
      CryptoService,
      FileSystem,
      LayoutResolver
    ]
end
