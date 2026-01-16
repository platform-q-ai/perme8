defmodule StaticSite.Domain.Entities.Page do
  @moduledoc """
  Page entity represents a single page or blog post.

  This is a pure data structure with no business logic or I/O.
  Pages can be created from frontmatter metadata and rendered content.
  """

  @type t :: %__MODULE__{
          title: String.t(),
          content: String.t(),
          slug: String.t() | nil,
          url: String.t() | nil,
          date: DateTime.t() | nil,
          tags: list(String.t()),
          category: String.t() | nil,
          draft: boolean(),
          layout: String.t() | nil,
          frontmatter: map(),
          file_path: String.t() | nil
        }

  defstruct [
    :title,
    :content,
    :slug,
    :url,
    :date,
    :category,
    :layout,
    :file_path,
    tags: [],
    draft: false,
    frontmatter: %{}
  ]

  # Implement Access protocol to allow @page[:key] syntax in templates
  # This looks up fields in the struct first, then falls back to frontmatter
  @behaviour Access

  @impl Access
  def fetch(%__MODULE__{} = page, key) do
    # First check if it's a struct field
    if key in [
         :title,
         :content,
         :slug,
         :url,
         :date,
         :tags,
         :category,
         :draft,
         :layout,
         :frontmatter,
         :file_path
       ] do
      {:ok, Map.get(page, key)}
    else
      # Fall back to frontmatter for dynamic fields like :subtitle
      case Map.get(page.frontmatter, to_string(key)) do
        nil -> :error
        value -> {:ok, value}
      end
    end
  end

  @impl Access
  def get_and_update(%__MODULE__{} = page, key, fun) do
    current =
      case fetch(page, key) do
        {:ok, value} -> value
        :error -> nil
      end

    case fun.(current) do
      {get_value, new_value} ->
        # Update the struct field or frontmatter
        new_page =
          if key in [
               :title,
               :content,
               :slug,
               :url,
               :date,
               :tags,
               :category,
               :draft,
               :layout,
               :frontmatter,
               :file_path
             ] do
            Map.put(page, key, new_value)
          else
            %{page | frontmatter: Map.put(page.frontmatter, to_string(key), new_value)}
          end

        {get_value, new_page}

      :pop ->
        {current, page}
    end
  end

  @impl Access
  def pop(%__MODULE__{} = page, key) do
    case fetch(page, key) do
      {:ok, value} -> {value, page}
      :error -> {nil, page}
    end
  end

  @doc """
  Creates a new Page struct from attributes.

  ## Examples

      iex> Page.new(%{title: "My Post", content: "<p>Hello</p>", slug: "my-post", url: "/my-post.html"})
      %Page{title: "My Post", content: "<p>Hello</p>", slug: "my-post", url: "/my-post.html"}
  """
  @spec new(map()) :: t()
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Creates a Page struct from frontmatter map and rendered content.

  Parses frontmatter fields and converts them to appropriate types:
  - date: ISO 8601 string -> DateTime
  - tags: list of strings (defaults to [])
  - draft: boolean (defaults to false)

  ## Examples

      iex> frontmatter = %{"title" => "Post", "date" => "2024-01-15T10:30:00Z"}
      iex> Page.from_frontmatter(frontmatter, "<p>Content</p>")
      %Page{title: "Post", date: ~U[2024-01-15 10:30:00Z], content: "<p>Content</p>"}
  """
  @spec from_frontmatter(map(), String.t()) :: t()
  def from_frontmatter(frontmatter, content) do
    %__MODULE__{
      title: Map.get(frontmatter, "title"),
      content: content,
      date: parse_date(frontmatter["date"]),
      tags: Map.get(frontmatter, "tags", []),
      category: Map.get(frontmatter, "category"),
      draft: Map.get(frontmatter, "draft", false),
      layout: Map.get(frontmatter, "layout"),
      frontmatter: frontmatter
    }
  end

  # Private Helpers

  defp parse_date(nil), do: nil

  defp parse_date(date_string) when is_binary(date_string) do
    # Try parsing as full DateTime first
    case DateTime.from_iso8601(date_string) do
      {:ok, datetime, _offset} ->
        datetime

      {:error, _reason} ->
        # If that fails, try parsing as Date and convert to DateTime at midnight UTC
        case Date.from_iso8601(date_string) do
          {:ok, date} ->
            {:ok, datetime} = DateTime.new(date, ~T[00:00:00], "Etc/UTC")
            datetime

          {:error, _reason} ->
            nil
        end
    end
  end

  defp parse_date(_), do: nil
end
