defmodule Alkali.Application.UseCases.GenerateCollections do
  @moduledoc """
  GenerateCollections use case creates collections of pages grouped by tags and categories.

  This use case organizes pages into collections for rendering navigation, archives,
  and collection pages (e.g., all posts with a specific tag or in a category).
  """

  alias Alkali.Domain.Entities.{Page, Collection}

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
    all_tags = pages |> Enum.flat_map(& &1.tags) |> Enum.uniq()

    tag_collections =
      Enum.map(all_tags, fn tag_name ->
        tag_pages = filter_pages_for_tag(pages, tag_name, include_drafts)

        Collection.new(tag_name, :tag)
        |> Map.put(:pages, tag_pages)
        |> Collection.sort_by_date()
      end)

    collections ++ tag_collections
  end

  defp filter_pages_for_tag(pages, tag_name, true) do
    Enum.filter(pages, &Enum.member?(&1.tags, tag_name))
  end

  defp filter_pages_for_tag(pages, tag_name, false) do
    Enum.filter(pages, &(not &1.draft and Enum.member?(&1.tags, tag_name)))
  end

  defp build_category_collections(collections, pages, include_drafts) do
    all_categories = pages |> Enum.map(& &1.category) |> Enum.filter(& &1) |> Enum.uniq()

    category_collections =
      Enum.map(all_categories, fn category_name ->
        category_pages = filter_pages_for_category(pages, category_name, include_drafts)

        Collection.new(category_name, :category)
        |> Map.put(:pages, category_pages)
        |> Collection.sort_by_date()
      end)

    collections ++ category_collections
  end

  defp filter_pages_for_category(pages, category_name, true) do
    Enum.filter(pages, &(&1.category == category_name))
  end

  defp filter_pages_for_category(pages, category_name, false) do
    Enum.filter(pages, &(not &1.draft and &1.category == category_name))
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
