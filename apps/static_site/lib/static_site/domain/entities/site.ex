defmodule StaticSite.Domain.Entities.Site do
  @moduledoc """
  Site entity represents site configuration.

  This is a pure data structure containing all site-level configuration
  such as title, URL, author, and layout defaults.
  """

  @type t :: %__MODULE__{
          title: String.t() | nil,
          url: String.t() | nil,
          author: String.t() | nil,
          output_dir: String.t(),
          post_layout: String.t(),
          page_layout: String.t()
        }

  defstruct [
    :title,
    :url,
    :author,
    output_dir: "_site",
    post_layout: "default",
    page_layout: "default"
  ]

  @doc """
  Creates a new Site struct from attributes.

  Provides sensible defaults:
  - output_dir: "_site"
  - post_layout: "default"
  - page_layout: "default"

  ## Examples

      iex> Site.new(%{title: "My Blog", url: "https://example.com"})
      %Site{title: "My Blog", url: "https://example.com", output_dir: "_site"}
  """
  @spec new(map()) :: t()
  def new(attrs) do
    struct(__MODULE__, attrs)
  end

  @doc """
  Validates site configuration.

  Required fields:
  - title: must be present
  - url: must be present and valid URL format

  ## Examples

      iex> Site.validate(%{title: "Blog", url: "https://example.com"})
      {:ok, %Site{title: "Blog", url: "https://example.com"}}

      iex> Site.validate(%{})
      {:error, ["title is required", "url is required"]}
  """
  @spec validate(map()) :: {:ok, t()} | {:error, list(String.t())}
  def validate(attrs) do
    errors =
      []
      |> validate_required_field(attrs, "title")
      |> validate_required_field(attrs, "url")
      |> validate_url_format(attrs)

    case errors do
      [] -> {:ok, new(attrs)}
      errors -> {:error, Enum.reverse(errors)}
    end
  end

  # Private Helpers

  defp validate_required_field(errors, attrs, field) do
    if Map.has_key?(attrs, String.to_atom(field)) || Map.has_key?(attrs, field) do
      errors
    else
      ["#{field} is required" | errors]
    end
  end

  defp validate_url_format(errors, attrs) do
    url = Map.get(attrs, :url) || Map.get(attrs, "url")

    cond do
      is_nil(url) ->
        errors

      valid_url?(url) ->
        errors

      true ->
        ["url must be a valid URL" | errors]
    end
  end

  defp valid_url?(url) when is_binary(url) do
    uri = URI.parse(url)
    uri.scheme in ["http", "https"] && uri.host != nil
  end

  defp valid_url?(_), do: false
end
