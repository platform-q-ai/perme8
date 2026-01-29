defmodule Alkali.Infrastructure.Renderers.CollectionRenderer do
  @moduledoc """
  Infrastructure renderer for collection pages.

  This module handles all HTML generation for collection pages including:
  - Post list items
  - Pagination controls
  - Collection metadata

  By extracting presentation logic to the infrastructure layer, we maintain
  Clean Architecture boundaries where use cases orchestrate behavior without
  containing presentation details.
  """

  @doc """
  Renders a single post item as HTML.

  ## Parameters

    - `page` - A page map with title, url, date, and frontmatter
    - `opts` - Rendering options (reserved for future use)

  ## Returns

  An HTML string representing the post item.

  ## Examples

      iex> page = %{title: "My Post", url: "/posts/my-post", date: ~D[2024-01-15]}
      iex> CollectionRenderer.render_post_item(page)
      "<article class=\\"post-item\\">..."
  """
  @spec render_post_item(map(), keyword()) :: String.t()
  def render_post_item(page, _opts \\ []) do
    relative_url = build_relative_url(page.url)
    formatted_date = format_post_date(page.date)
    intro = extract_intro(page)

    intro_html = if intro != "", do: ~s(<p class="post-intro">#{intro}</p>), else: ""

    date_html =
      if formatted_date != "", do: ~s(<time class="post-date">#{formatted_date}</time>), else: ""

    """
    <article class="post-item">
      <h3 class="post-title"><a href="#{relative_url}">#{page.title}</a></h3>
      #{intro_html}
      #{date_html}
    </article>
    """
  end

  @doc """
  Renders a list of posts as HTML.

  ## Parameters

    - `pages` - List of page maps
    - `opts` - Rendering options (reserved for future use)

  ## Returns

  An HTML string containing all post items.
  """
  @spec render_posts_list(list(map()), keyword()) :: String.t()
  def render_posts_list(pages, opts \\ []) do
    Enum.map_join(pages, "\n", &render_post_item(&1, opts))
  end

  @doc """
  Renders pagination controls as HTML.

  ## Parameters

    - `pagination` - A pagination struct with:
      - `has_prev` - boolean
      - `has_next` - boolean
      - `prev_url` - previous page URL (optional)
      - `next_url` - next page URL
      - `current_page` - current page number
      - `page_numbers` - list of page numbers
    - `opts` - Rendering options (reserved for future use)

  ## Returns

  An HTML string containing pagination navigation.
  """
  @spec render_pagination(map(), keyword()) :: String.t()
  def render_pagination(pagination, _opts \\ []) do
    prev_link = render_prev_link(pagination)
    next_link = render_next_link(pagination)
    page_links = render_page_links(pagination)

    """
    <nav class="pagination">
      #{prev_link}
      <span class="pagination-pages">#{page_links}</span>
      #{next_link}
    </nav>
    """
  end

  @doc """
  Renders complete collection content with metadata.

  ## Parameters

    - `collection` - Collection struct with type, name, and pages
    - `pagination` - Pagination struct (optional, nil for non-paginated)
    - `opts` - Rendering options (reserved for future use)

  ## Returns

  A tuple of `{title, content}` where title is the page title and content is the HTML.
  """
  @spec render_collection_content(map(), map() | nil, keyword()) :: {String.t(), String.t()}
  def render_collection_content(collection, pagination, opts \\ []) do
    posts_html = render_posts_list(collection.pages, opts)
    pagination_html = if pagination, do: render_pagination(pagination, opts), else: ""

    page_info = pagination_page_info(pagination)
    count = Enum.count(collection.pages)

    case collection.type do
      :posts ->
        {"All Posts#{page_info}",
         collection_html("Total posts: #{count}", posts_html, pagination_html)}

      type when type in [:tag, :category] ->
        type_name = String.capitalize(to_string(type))

        {"#{type_name}: #{collection.name}#{page_info}",
         collection_html("Posts: #{count}", posts_html, pagination_html)}

      _ ->
        type_name = String.capitalize(to_string(collection.type))
        {"#{type_name}: #{collection.name}", collection_html("Posts: #{count}", posts_html, "")}
    end
  end

  # Private helpers

  defp build_relative_url(url) do
    relative = String.trim_leading(url, "/")
    if relative != "", do: "../#{relative}", else: "../index.html"
  end

  defp format_post_date(nil), do: ""
  defp format_post_date(date), do: Calendar.strftime(date, "%B %d, %Y")

  defp extract_intro(%{frontmatter: fm}) when is_map(fm) do
    Map.get(fm, "intro") || Map.get(fm, "description") || ""
  end

  defp extract_intro(_), do: ""

  defp render_prev_link(pagination) do
    if pagination.has_prev do
      prev_url = pagination.prev_url || "../index.html"
      ~s(<a href="#{prev_url}" class="pagination-prev">&larr; Previous</a>)
    else
      ~s(<span class="pagination-prev disabled">&larr; Previous</span>)
    end
  end

  defp render_next_link(pagination) do
    if pagination.has_next do
      ~s(<a href="#{pagination.next_url}" class="pagination-next">Next &rarr;</a>)
    else
      ~s(<span class="pagination-next disabled">Next &rarr;</span>)
    end
  end

  defp render_page_links(pagination) do
    Enum.map_join(pagination.page_numbers, " ", fn page_num ->
      url = if page_num == 1, do: "../index.html", else: "../page/#{page_num}.html"

      if page_num == pagination.current_page do
        ~s(<span class="pagination-page current">#{page_num}</span>)
      else
        ~s(<a href="#{url}" class="pagination-page">#{page_num}</a>)
      end
    end)
  end

  defp pagination_page_info(nil), do: ""
  defp pagination_page_info(p), do: " (Page #{p.current_page} of #{p.total_pages})"

  defp collection_html(meta, posts_html, pagination_html) do
    """
    <p class="collection-meta">#{meta}</p>
    <div class="posts">
      #{posts_html}
    </div>
    #{pagination_html}
    """
  end
end
