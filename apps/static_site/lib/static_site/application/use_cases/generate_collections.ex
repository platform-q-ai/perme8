defmodule StaticSite.Application.UseCases.GenerateCollections do
  @moduledoc """
  GenerateCollections use case creates collections of pages grouped by tags and categories.

  This use case organizes pages into collections for rendering navigation, archives,
  and collection pages (e.g., all posts with a specific tag or in a category).
  """

  alias StaticSite.Domain.Entities.{Page, Collection}

  @doc """
  Generates collections from a list of pages.

  ## Options

  - `:include_drafts` - Include draft pages in collections (default: false)

  ## Returns

  - `{:ok, list(Collection.t())}` on success
  - `{:error, String.t()}` on failure

  ## Examples

      iex> pages = [%Page{title: "Post", tags: ["elixir"], draft: false}]
      iex> GenerateCollections.execute(pages)
      {:ok, [%Collection{name: "elixir", type: :tag, pages: [%Page{...}]}]}
  """
  @spec execute(list(Page.t()), keyword()) :: {:ok, list(Collection.t())} | {:error, String.t()}
  def execute(pages, opts \\ []) do
    include_drafts = Keyword.get(opts, :include_drafts, false)

    # Group by tags and categories, and create a general posts collection
    collections =
      []
      |> build_tag_collections(pages, include_drafts)
      |> build_category_collections(pages, include_drafts)
      |> build_all_posts_collection(pages, include_drafts)

    {:ok, collections}
  end

  # Private Functions

  defp build_tag_collections(collections, pages, include_drafts) do
    # Extract all unique tags from ALL pages
    all_tags =
      pages
      |> Enum.flat_map(& &1.tags)
      |> Enum.uniq()

    # Create a collection for each tag
    tag_collections =
      Enum.map(all_tags, fn tag_name ->
        # Filter pages for this tag based on include_drafts
        tag_pages =
          if include_drafts do
            Enum.filter(pages, &Enum.member?(&1.tags, tag_name))
          else
            pages
            |> Enum.filter(&(&1.draft == false))
            |> Enum.filter(&Enum.member?(&1.tags, tag_name))
          end

        # Create and sort collection
        Collection.new(tag_name, :tag)
        |> Map.put(:pages, tag_pages)
        |> Collection.sort_by_date()
      end)

    collections ++ tag_collections
  end

  defp build_category_collections(collections, pages, include_drafts) do
    # Extract all unique categories from ALL pages
    all_categories =
      pages
      |> Enum.map(& &1.category)
      # Remove nil categories
      |> Enum.filter(& &1)
      |> Enum.uniq()

    # Create a collection for each category
    category_collections =
      Enum.map(all_categories, fn category_name ->
        # Filter pages for this category based on include_drafts
        category_pages =
          if include_drafts do
            Enum.filter(pages, &(&1.category == category_name))
          else
            pages
            |> Enum.filter(&(&1.draft == false))
            |> Enum.filter(&(&1.category == category_name))
          end

        # Create and sort collection
        Collection.new(category_name, :category)
        |> Map.put(:pages, category_pages)
        |> Collection.sort_by_date()
      end)

    collections ++ category_collections
  end

  defp build_all_posts_collection(collections, pages, include_drafts) do
    # A page is considered a "post" if its layout is "post" or it has a date
    # and is not explicitly a "page" layout.
    post_pages =
      pages
      |> Enum.filter(fn page ->
        (page.layout == "post" || (page.date != nil && page.layout != "page")) &&
          (include_drafts || not page.draft)
      end)

    # Only create posts collection if there are post pages
    if Enum.empty?(post_pages) do
      collections
    else
      collection =
        Collection.new("posts", :posts)
        |> Map.put(:pages, post_pages)
        |> Collection.sort_by_date()

      collections ++ [collection]
    end
  end
end
