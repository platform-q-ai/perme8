defmodule Alkali.Application.UseCases.GenerateRssFeed do
  @moduledoc """
  GenerateRssFeed use case creates an RSS feed for blog posts.

  This use case generates an RSS 2.0 compliant XML feed that can be used
  by feed readers to subscribe to blog updates.

  XML generation is delegated to the infrastructure layer (RssRenderer)
  following Clean Architecture principles.
  """

  alias Alkali.Domain.Entities.Page
  alias Alkali.Infrastructure.Renderers.RssRenderer

  @doc """
  Generates an RSS feed from a list of pages.

  ## Options

  - `:feed_title` - Title of the feed (default: "Blog")
  - `:feed_description` - Description of the feed (default: "Latest posts")
  - `:site_url` - Base URL of the site (required)
  - `:feed_url` - URL of the feed itself (default: site_url/feed.xml)
  - `:max_items` - Maximum number of items to include (default: 20)
  - `:rss_renderer` - Module for rendering RSS XML (default: RssRenderer)

  ## Returns

  - `{:ok, xml_string}` on success
  - `{:error, String.t()}` on failure

  ## Examples

      iex> pages = [%Page{title: "Post", url: "/post.html", date: ~D[2024-01-01]}]
      iex> GenerateRssFeed.execute(pages, site_url: "https://example.com")
      {:ok, "<?xml version=\\"1.0\\" encoding=\\"UTF-8\\"?>..."}
  """
  @spec execute(list(Page.t()), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def execute(pages, opts \\ []) do
    site_url = Keyword.get(opts, :site_url)

    if is_nil(site_url) || site_url == "" do
      {:error, "site_url is required for RSS feed generation"}
    else
      generate_feed(pages, site_url, opts)
    end
  end

  # Private Functions

  defp generate_feed(pages, site_url, opts) do
    feed_title = Keyword.get(opts, :feed_title, "Blog")
    feed_description = Keyword.get(opts, :feed_description, "Latest posts")
    feed_url = Keyword.get(opts, :feed_url, "#{site_url}/feed.xml")
    max_items = Keyword.get(opts, :max_items, 20)
    rss_renderer = Keyword.get(opts, :rss_renderer, RssRenderer)

    # Filter to only posts with dates (posts typically have /posts/ in their URL)
    # and exclude drafts
    feed_items =
      pages
      |> Enum.filter(&(&1.date != nil && &1.draft == false && post?(&1)))
      |> Enum.sort_by(& &1.date, {:desc, Date})
      |> Enum.take(max_items)

    # Delegate XML generation to infrastructure renderer
    rss_xml =
      rss_renderer.render_feed(
        feed_title,
        feed_description,
        site_url,
        feed_url,
        feed_items,
        opts
      )

    {:ok, rss_xml}
  end

  defp post?(%{url: url}) when is_binary(url) do
    # Check if URL contains /posts/ to identify blog posts vs regular pages
    String.contains?(url, "/posts/")
  end

  defp post?(_), do: false
end
