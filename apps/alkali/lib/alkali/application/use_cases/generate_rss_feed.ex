defmodule Alkali.Application.UseCases.GenerateRssFeed do
  @moduledoc """
  GenerateRssFeed use case creates an RSS feed for blog posts.

  This use case generates an RSS 2.0 compliant XML feed that can be used
  by feed readers to subscribe to blog updates.
  """

  alias Alkali.Domain.Entities.Page

  @doc """
  Generates an RSS feed from a list of pages.

  ## Options

  - `:feed_title` - Title of the feed (default: "Blog")
  - `:feed_description` - Description of the feed (default: "Latest posts")
  - `:site_url` - Base URL of the site (required)
  - `:feed_url` - URL of the feed itself (default: site_url/feed.xml)
  - `:max_items` - Maximum number of items to include (default: 20)

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
      feed_title = Keyword.get(opts, :feed_title, "Blog")
      feed_description = Keyword.get(opts, :feed_description, "Latest posts")
      feed_url = Keyword.get(opts, :feed_url, "#{site_url}/feed.xml")
      max_items = Keyword.get(opts, :max_items, 20)

      # Filter to only posts with dates (posts typically have /posts/ in their URL)
      # and exclude drafts
      feed_items =
        pages
        |> Enum.filter(&(&1.date != nil && &1.draft == false && is_post?(&1)))
        |> Enum.sort_by(& &1.date, {:desc, Date})
        |> Enum.take(max_items)

      rss_xml = build_rss_xml(feed_title, feed_description, site_url, feed_url, feed_items)

      {:ok, rss_xml}
    end
  end

  # Private Functions

  defp build_rss_xml(feed_title, feed_description, site_url, feed_url, items) do
    current_datetime = DateTime.utc_now() |> format_rfc822()

    items_xml = Enum.map(items, &build_item_xml(&1, site_url)) |> Enum.join("\n    ")

    """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
      <channel>
        <title>#{escape_xml(feed_title)}</title>
        <description>#{escape_xml(feed_description)}</description>
        <link>#{escape_xml(site_url)}</link>
        <atom:link href="#{escape_xml(feed_url)}" rel="self" type="application/rss+xml"/>
        <lastBuildDate>#{current_datetime}</lastBuildDate>
        <generator>Alkali</generator>
        #{items_xml}
      </channel>
    </rss>
    """
  end

  defp build_item_xml(page, site_url) do
    item_url = build_absolute_url(site_url, page.url)
    pub_date = format_rfc822(page.date)

    # Use first paragraph of content as description, or truncate
    description = extract_description(page.content)

    """
    <item>
      <title>#{escape_xml(page.title)}</title>
      <link>#{escape_xml(item_url)}</link>
      <guid>#{escape_xml(item_url)}</guid>
      <pubDate>#{pub_date}</pubDate>
      <description>#{escape_xml(description)}</description>
    </item>
    """
  end

  defp build_absolute_url(site_url, path) do
    # Remove trailing slash from site_url and leading slash from path
    site_url = String.trim_trailing(site_url, "/")
    path = String.trim_leading(path, "/")

    "#{site_url}/#{path}"
  end

  defp extract_description(content) when is_binary(content) do
    # Remove HTML tags and get first 200 characters
    content
    |> String.replace(~r/<[^>]*>/, "")
    |> String.trim()
    |> String.slice(0, 200)
    |> case do
      desc when byte_size(desc) >= 200 -> desc <> "..."
      desc -> desc
    end
  end

  defp extract_description(_), do: ""

  defp escape_xml(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  defp escape_xml(nil), do: ""

  defp format_rfc822(%Date{} = date) do
    # Convert Date to DateTime at midnight UTC for RFC822 formatting
    {:ok, datetime} = DateTime.new(date, ~T[00:00:00], "Etc/UTC")
    format_rfc822(datetime)
  end

  defp format_rfc822(%DateTime{} = datetime) do
    # Format as RFC822: "Fri, 15 Jan 2024 10:30:00 +0000"
    datetime
    |> DateTime.shift_zone!("Etc/UTC")
    |> Calendar.strftime("%a, %d %b %Y %H:%M:%S +0000")
  end

  defp is_post?(%{url: url}) when is_binary(url) do
    # Check if URL contains /posts/ to identify blog posts vs regular pages
    String.contains?(url, "/posts/")
  end

  defp is_post?(_), do: false
end
