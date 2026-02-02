defmodule Alkali.Application.Behaviours.RssRendererBehaviour do
  @moduledoc """
  Behaviour for RSS feed rendering operations.

  Defines the contract for renderers that generate XML for RSS 2.0 feeds
  including feed channel metadata, individual feed items, and XML formatting.
  """

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
  """
  @callback render_feed(String.t(), String.t(), String.t(), String.t(), list(map()), keyword()) ::
              String.t()
end
