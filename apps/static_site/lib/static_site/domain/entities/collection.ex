defmodule StaticSite.Domain.Entities.Collection do
  @moduledoc """
  Collection entity represents a group of pages (by tag or category).

  Collections are used to organize content and generate collection pages
  (e.g., all posts tagged "elixir" or in category "tutorials").
  """

  alias StaticSite.Domain.Entities.Page

  @type collection_type :: :tag | :category | :posts | :pages
  @type t :: %__MODULE__{
          name: String.t(),
          pages: list(Page.t()),
          type: collection_type()
        }

  defstruct [:name, :type, pages: []]

  @doc """
  Creates a new Collection.

  ## Examples

      iex> Collection.new("elixir", :tag)
      %Collection{name: "elixir", type: :tag, pages: []}
  """
  @spec new(String.t(), collection_type()) :: t()
  def new(name, type) do
    %__MODULE__{
      name: name,
      type: type,
      pages: []
    }
  end

  @doc """
  Adds a page to the collection.

  ## Examples

      iex> collection = Collection.new("elixir", :tag)
      iex> page = %Page{title: "My Post"}
      iex> Collection.add_page(collection, page)
      %Collection{pages: [%Page{title: "My Post"}]}
  """
  @spec add_page(t(), Page.t()) :: t()
  def add_page(%__MODULE__{pages: pages} = collection, page) do
    %{collection | pages: pages ++ [page]}
  end

  @doc """
  Sorts pages by date descending (newest first).

  Pages without dates are sorted to the end.

  ## Examples

      iex> collection = %Collection{pages: [old_page, new_page]}
      iex> Collection.sort_by_date(collection)
      %Collection{pages: [new_page, old_page]}
  """
  @spec sort_by_date(t()) :: t()
  def sort_by_date(%__MODULE__{pages: pages} = collection) do
    sorted_pages =
      Enum.sort_by(pages, & &1.date, fn
        nil, nil -> true
        nil, _ -> false
        _, nil -> true
        date1, date2 -> DateTime.compare(date1, date2) == :gt
      end)

    %{collection | pages: sorted_pages}
  end
end
