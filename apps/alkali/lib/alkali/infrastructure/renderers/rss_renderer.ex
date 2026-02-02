defmodule Alkali.Infrastructure.Renderers.RssRenderer do
  @moduledoc """
  Infrastructure renderer for RSS feed generation.

  This module handles all XML generation for RSS 2.0 feeds including:
  - Feed channel metadata
  - Individual feed items
  - XML escaping and formatting

  By extracting XML generation to the infrastructure layer, we maintain
  Clean Architecture boundaries where use cases orchestrate behavior without
  containing presentation details.
  """

  @behaviour Alkali.Application.Behaviours.RssRendererBehaviour

  @doc """
  Renders a complete RSS 2.0 feed as XML.

  ## Parameters

    - `feed_title` - Title of the feed
    - `feed_description` - Description of the feed
    - `site_url` - Base URL of the site
    - `feed_url` - URL of the feed itself
    - `items` - List of page maps to include as items
    - `opts` - Rendering options (reserved for future use)

  ## Returns

  An XML string representing the complete RSS feed.

  ## Examples

      iex> RssRenderer.render_feed("My Blog", "Latest posts", "https://example.com", "https://example.com/feed.xml", pages)
      "<?xml version=\\"1.0\\" encoding=\\"UTF-8\\"?>..."
  """
  @impl true
  @spec render_feed(String.t(), String.t(), String.t(), String.t(), list(map()), keyword()) ::
          String.t()
  def render_feed(feed_title, feed_description, site_url, feed_url, items, _opts \\ []) do
    current_datetime = DateTime.utc_now() |> format_rfc822()

    items_xml = Enum.map_join(items, "\n    ", &render_item(&1, site_url))

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

  @doc """
  Renders a single RSS item as XML.

  ## Parameters

    - `page` - A page map with title, url, date, and content
    - `site_url` - Base URL of the site
    - `opts` - Rendering options (reserved for future use)

  ## Returns

  An XML string representing the RSS item.
  """
  @spec render_item(map(), String.t(), keyword()) :: String.t()
  def render_item(page, site_url, _opts \\ []) do
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

  @doc """
  Escapes special XML characters in a string.

  ## Parameters

    - `text` - The string to escape

  ## Returns

  The escaped string safe for XML inclusion.
  """
  @spec escape_xml(String.t() | nil) :: String.t()
  def escape_xml(text) when is_binary(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  def escape_xml(nil), do: ""

  @doc """
  Formats a date or datetime as RFC822 format for RSS.

  ## Parameters

    - `date` - A Date or DateTime struct

  ## Returns

  A string in RFC822 format (e.g., "Fri, 15 Jan 2024 10:30:00 +0000").
  """
  @spec format_rfc822(Date.t() | DateTime.t()) :: String.t()
  def format_rfc822(%Date{} = date) do
    # Convert Date to DateTime at midnight UTC for RFC822 formatting
    {:ok, datetime} = DateTime.new(date, ~T[00:00:00], "Etc/UTC")
    format_rfc822(datetime)
  end

  def format_rfc822(%DateTime{} = datetime) do
    # Format as RFC822: "Fri, 15 Jan 2024 10:30:00 +0000"
    datetime
    |> DateTime.shift_zone!("Etc/UTC")
    |> Calendar.strftime("%a, %d %b %Y %H:%M:%S +0000")
  end

  # Private helpers

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
end
