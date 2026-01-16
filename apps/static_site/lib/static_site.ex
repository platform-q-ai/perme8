defmodule StaticSite do
  @moduledoc """
  Public API for Static Site Generator.

  This module provides high-level functions for working with the static site generator.
  It delegates to the application layer use cases for most operations.
  """

  alias StaticSite.Application.UseCases.{
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

  See `StaticSite.Application.UseCases.ScaffoldNewSite.execute/2` for options.
  """
  defdelegate new_site(site_path, opts \\ []), to: ScaffoldNewSite, as: :execute

  @doc """
  Creates a new post.

  See `StaticSite.Application.UseCases.CreateNewPost.execute/2` for options.
  """
  defdelegate new_post(title, opts \\ []), to: CreateNewPost, as: :execute

  @doc """
  Parses content files.

  See `StaticSite.Application.UseCases.ParseContent.execute/2` for options.
  """
  defdelegate parse_content(path, opts \\ []), to: ParseContent, as: :execute

  @doc """
  Generates collections from pages.

  See `StaticSite.Application.UseCases.GenerateCollections.execute/2` for options.
  """
  defdelegate generate_collections(pages, opts \\ []), to: GenerateCollections, as: :execute

  @doc """
  Processes assets.

  See `StaticSite.Application.UseCases.ProcessAssets.execute/2` for options.
  """
  defdelegate process_assets(assets, opts \\ []), to: ProcessAssets, as: :execute

  @doc """
  Builds the complete static site.

  See `StaticSite.Application.UseCases.BuildSite.execute/2` for options.
  """
  defdelegate build_site(site_path, opts \\ []), to: BuildSite, as: :execute

  @doc """
  Cleans the output directory.

  See `StaticSite.Application.UseCases.CleanOutput.execute/2` for options.
  """
  defdelegate clean_output(site_path, opts \\ []), to: CleanOutput, as: :execute

  @doc false
  def hello, do: :world
end
