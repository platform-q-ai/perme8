defmodule Alkali.ApplicationLayer do
  @moduledoc """
  Application layer namespace for the Alkali static site generator.

  The application layer contains:

  - **Use Cases** (`Alkali.Application.UseCases.*`) - Business operations
    - `BuildSite` - Orchestrates the complete site build
    - `CleanOutput` - Cleans the output directory
    - `CreateNewPost` - Creates a new blog post
    - `GenerateCollections` - Groups pages into collections
    - `GenerateRssFeed` - Generates RSS feed XML
    - `ParseContent` - Parses markdown content files
    - `ProcessAssets` - Processes and fingerprints assets
    - `ScaffoldNewSite` - Creates a new site structure

  - **Behaviours** (`Alkali.Application.Behaviours.*`) - Abstractions
    - `FileSystemBehaviour` - File system operations contract
    - `BuildCacheBehaviour` - Build caching contract
    - `ConfigLoaderBehaviour` - Configuration loading contract
    - `LayoutResolverBehaviour` - Layout resolution contract

  - **Helpers** (`Alkali.Application.Helpers.*`) - Shared utilities
    - `Paginate` - Pagination logic

  ## Boundary Rules

  The application layer depends on:
  - Domain layer (entities, policies)

  The application layer does NOT depend on:
  - Infrastructure layer (implementations)
  - External libraries (except through behaviours)

  Infrastructure is injected via options at runtime.
  """

  use Boundary,
    deps: [Alkali.Domain],
    exports: [
      UseCases.BuildSite,
      UseCases.CleanOutput,
      UseCases.CreateNewPost,
      UseCases.GenerateCollections,
      UseCases.GenerateRssFeed,
      UseCases.ParseContent,
      UseCases.ProcessAssets,
      UseCases.ScaffoldNewSite,
      Behaviours.FileSystemBehaviour,
      Behaviours.BuildCacheBehaviour,
      Behaviours.ConfigLoaderBehaviour,
      Behaviours.LayoutResolverBehaviour,
      Helpers.Paginate
    ]
end
