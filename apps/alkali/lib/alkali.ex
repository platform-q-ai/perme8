defmodule Alkali do
  @moduledoc """
  Public API for Static Site Generator.

  This module provides high-level functions for working with the static site generator.
  It delegates to the application layer use cases for most operations.

  ## Architecture Boundaries

  This application follows Clean Architecture with the following layers:

  - **Domain** (`Alkali.Domain`) - Entities and policies, no dependencies
  - **Application** (`Alkali.Application`) - Use cases and behaviours, depends on domain
  - **Infrastructure** (`Alkali.Infrastructure`) - External concerns, implements behaviours
  - **Interface** (`Mix.Tasks.Alkali.*`) - CLI, depends on public API only
  """

  use Boundary,
    deps: [Alkali.ApplicationLayer, Alkali.InfrastructureLayer],
    exports: []

  alias Alkali.Application.UseCases.{
    ScaffoldNewSite,
    CreateNewPost,
    ParseContent,
    GenerateCollections,
    ProcessAssets,
    BuildSite,
    CleanOutput
  }

  @doc """
  Creates a new static site project.

  See `Alkali.Application.UseCases.ScaffoldNewSite.execute/2` for options.
  """
  defdelegate new_site(site_path, opts \\ []), to: ScaffoldNewSite, as: :execute

  @doc """
  Creates a new post.

  See `Alkali.Application.UseCases.CreateNewPost.execute/2` for options.
  """
  defdelegate new_post(title, opts \\ []), to: CreateNewPost, as: :execute

  @doc """
  Parses content files.

  See `Alkali.Application.UseCases.ParseContent.execute/2` for options.
  """
  defdelegate parse_content(path, opts \\ []), to: ParseContent, as: :execute

  @doc """
  Generates collections from pages.

  See `Alkali.Application.UseCases.GenerateCollections.execute/2` for options.
  """
  defdelegate generate_collections(pages, opts \\ []), to: GenerateCollections, as: :execute

  @doc """
  Processes assets.

  See `Alkali.Application.UseCases.ProcessAssets.execute/2` for options.
  """
  defdelegate process_assets(assets, opts \\ []), to: ProcessAssets, as: :execute

  @doc """
  Builds the complete static site.

  See `Alkali.Application.UseCases.BuildSite.execute/2` for options.
  """
  defdelegate build_site(site_path, opts \\ []), to: BuildSite, as: :execute

  @doc """
  Cleans the output directory.

  See `Alkali.Application.UseCases.CleanOutput.execute/2` for options.
  """
  defdelegate clean_output(site_path, opts \\ []), to: CleanOutput, as: :execute

  @doc """
  Hello world function for testing.

  ## Examples

      iex> Alkali.hello()
      :world

  """
  def hello do
    :world
  end
end
