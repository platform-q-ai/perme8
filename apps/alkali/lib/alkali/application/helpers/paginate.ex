defmodule Alkali.Application.Helpers.Paginate do
  @moduledoc """
  Paginate helper module for splitting collections into pages.

  This module provides utilities for paginating lists of items and
  generating pagination metadata for navigation.
  """

  @type pagination_meta :: %{
          current_page: pos_integer(),
          total_pages: pos_integer(),
          per_page: pos_integer(),
          total_items: non_neg_integer(),
          has_prev: boolean(),
          has_next: boolean(),
          prev_url: String.t() | nil,
          next_url: String.t() | nil,
          page_numbers: list(pos_integer())
        }

  @type page :: %{
          items: list(any()),
          page_number: pos_integer(),
          pagination: pagination_meta()
        }

  @doc """
  Paginates a list of items into pages.

  ## Options

  - `:per_page` - Number of items per page (default: 10)
  - `:url_template` - Template for generating page URLs (default: "/page/:page")
    - `:page` placeholder will be replaced with page number
    - First page (1) returns `nil` for URL (uses index page)

  ## Returns

  List of page maps with items and pagination metadata.

  ## Examples

      iex> items = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
      iex> pages = Paginate.paginate(items, per_page: 5, url_template: "/posts/page/:page")
      iex> length(pages)
      3
      iex> hd(pages).items
      [1, 2, 3, 4, 5]
      iex> hd(pages).pagination.current_page
      1
  """
  @spec paginate(list(any()), keyword()) :: list(page())
  def paginate(items, opts \\ []) do
    per_page = Keyword.get(opts, :per_page, 10)
    url_template = Keyword.get(opts, :url_template, "/page/:page")

    total_items = length(items)
    total_pages = calculate_total_pages(total_items, per_page)

    items
    |> Enum.chunk_every(per_page)
    |> Enum.with_index(1)
    |> Enum.map(fn {page_items, page_number} ->
      pagination =
        build_pagination_meta(
          page_number,
          total_pages,
          per_page,
          total_items,
          url_template
        )

      %{
        items: page_items,
        page_number: page_number,
        pagination: pagination
      }
    end)
  end

  @doc """
  Calculates total number of pages needed for given items and per_page.

  ## Examples

      iex> Paginate.calculate_total_pages(100, 10)
      10
      iex> Paginate.calculate_total_pages(95, 10)
      10
      iex> Paginate.calculate_total_pages(0, 10)
      1
  """
  @spec calculate_total_pages(non_neg_integer(), pos_integer()) :: pos_integer()
  def calculate_total_pages(total_items, _per_page) when total_items <= 0 do
    1
  end

  def calculate_total_pages(total_items, per_page) do
    (total_items / per_page) |> Float.ceil() |> trunc()
  end

  @doc """
  Builds pagination metadata for a specific page.

  ## Examples

      iex> Paginate.build_pagination_meta(1, 3, 10, 25, "/posts/page/:page")
      %{
        current_page: 1,
        total_pages: 3,
        per_page: 10,
        total_items: 25,
        has_prev: false,
        has_next: true,
        prev_url: nil,
        next_url: "/posts/page/2",
        page_numbers: [1, 2, 3]
      }
  """
  @spec build_pagination_meta(
          pos_integer(),
          pos_integer(),
          pos_integer(),
          non_neg_integer(),
          String.t()
        ) :: pagination_meta()
  def build_pagination_meta(current_page, total_pages, per_page, total_items, url_template) do
    has_prev = current_page > 1
    has_next = current_page < total_pages

    %{
      current_page: current_page,
      total_pages: total_pages,
      per_page: per_page,
      total_items: total_items,
      has_prev: has_prev,
      has_next: has_next,
      prev_url: if(has_prev, do: build_page_url(current_page - 1, url_template), else: nil),
      next_url: if(has_next, do: build_page_url(current_page + 1, url_template), else: nil),
      page_numbers: Enum.to_list(1..total_pages)
    }
  end

  @doc """
  Builds URL for a specific page number.

  Returns nil for page 1 (index page), otherwise replaces :page placeholder.

  ## Examples

      iex> Paginate.build_page_url(1, "/posts/page/:page")
      nil
      iex> Paginate.build_page_url(2, "/posts/page/:page")
      "/posts/page/2"
      iex> Paginate.build_page_url(5, "/categories/:category/page/:page", category: "elixir")
      "/categories/elixir/page/5"
  """
  @spec build_page_url(pos_integer(), String.t(), keyword()) :: String.t() | nil
  def build_page_url(page_number, url_template, replacements \\ [])

  def build_page_url(1, _url_template, _replacements) do
    # Page 1 is the index page, so return nil (no pagination suffix)
    nil
  end

  def build_page_url(page_number, url_template, replacements) do
    # Replace :page placeholder
    url = String.replace(url_template, ":page", to_string(page_number))

    # Replace any additional placeholders from replacements keyword list
    Enum.reduce(replacements, url, fn {key, value}, acc ->
      String.replace(acc, ":#{key}", to_string(value))
    end)
  end

  @doc """
  Generates file path for a paginated page.

  ## Examples

      iex> Paginate.page_file_path("/posts", 1)
      "/posts/index.html"
      iex> Paginate.page_file_path("/posts", 2)
      "/posts/page/2.html"
      iex> Paginate.page_file_path("/categories/elixir", 3)
      "/categories/elixir/page/3.html"
  """
  @spec page_file_path(String.t(), pos_integer()) :: String.t()
  def page_file_path(base_path, page_number) when page_number == 1 do
    "#{base_path}/index.html"
  end

  def page_file_path(base_path, page_number) do
    "#{base_path}/page/#{page_number}.html"
  end
end
