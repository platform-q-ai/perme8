defmodule Alkali.Application do
  @moduledoc """
  Application layer boundary for the Alkali static site generator.

  This module serves dual purposes:
  1. OTP Application supervision tree
  2. Boundary definition for the application layer

  Contains orchestration logic that coordinates domain and infrastructure:

  ## Behaviours (Interfaces for Infrastructure)
  - `Alkali.Application.Behaviours.BuildCacheBehaviour` - Build cache operations
  - `Alkali.Application.Behaviours.ConfigLoaderBehaviour` - Configuration loading
  - `Alkali.Application.Behaviours.FileSystemBehaviour` - File system operations
  - `Alkali.Application.Behaviours.LayoutResolverBehaviour` - Layout resolution

  ## Helpers
  - `Alkali.Application.Helpers.Paginate` - Pagination utilities

  ## Use Cases
  - `Alkali.Application.UseCases.BuildSite` - Full site build orchestration
  - `Alkali.Application.UseCases.CleanOutput` - Output directory cleanup
  - `Alkali.Application.UseCases.CreateNewPost` - New post creation
  - `Alkali.Application.UseCases.GenerateCollections` - Collection generation
  - `Alkali.Application.UseCases.GenerateRssFeed` - RSS feed generation
  - `Alkali.Application.UseCases.ParseContent` - Content file parsing
  - `Alkali.Application.UseCases.ProcessAssets` - Asset processing
  - `Alkali.Application.UseCases.ScaffoldNewSite` - New site scaffolding

  ## Dependency Rule

  The Application layer may only depend on:
  - Domain layer (same context)

  It cannot import:
  - Infrastructure layer (repos, file system, parsers)
  - Other contexts directly (use dependency injection)
  """

  # Force compilation order - these modules must compile before this boundary
  require Alkali.Application.Behaviours.BuildCacheBehaviour
  require Alkali.Application.Behaviours.ConfigLoaderBehaviour
  require Alkali.Application.Behaviours.FileSystemBehaviour
  require Alkali.Application.Behaviours.LayoutResolverBehaviour
  require Alkali.Application.Behaviours.CryptoServiceBehaviour
  require Alkali.Application.Behaviours.FrontmatterParserBehaviour
  require Alkali.Application.Behaviours.MarkdownParserBehaviour
  require Alkali.Application.Behaviours.CollectionRendererBehaviour
  require Alkali.Application.Behaviours.RssRendererBehaviour
  require Alkali.Application.Helpers.Paginate
  require Alkali.Application.UseCases.BuildSite
  require Alkali.Application.UseCases.CleanOutput
  require Alkali.Application.UseCases.CreateNewPost
  require Alkali.Application.UseCases.GenerateCollections
  require Alkali.Application.UseCases.GenerateRssFeed
  require Alkali.Application.UseCases.ParseContent
  require Alkali.Application.UseCases.ProcessAssets
  require Alkali.Application.UseCases.ScaffoldNewSite

  use Boundary,
    top_level?: true,
    deps: [Alkali.Domain],
    exports: [
      # Behaviours (interfaces for Infrastructure to implement)
      Behaviours.BuildCacheBehaviour,
      Behaviours.ConfigLoaderBehaviour,
      Behaviours.FileSystemBehaviour,
      Behaviours.LayoutResolverBehaviour,
      Behaviours.CryptoServiceBehaviour,
      Behaviours.FrontmatterParserBehaviour,
      Behaviours.MarkdownParserBehaviour,
      Behaviours.CollectionRendererBehaviour,
      Behaviours.RssRendererBehaviour,
      # Helpers
      Helpers.Paginate,
      # Use Cases
      UseCases.BuildSite,
      UseCases.CleanOutput,
      UseCases.CreateNewPost,
      UseCases.GenerateCollections,
      UseCases.GenerateRssFeed,
      UseCases.ParseContent,
      UseCases.ProcessAssets,
      UseCases.ScaffoldNewSite
    ]

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: Alkali.Worker.start_link(arg)
      # {Alkali.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Alkali.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
