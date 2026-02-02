defmodule Alkali.Application.Behaviours.LayoutResolverBehaviour do
  @moduledoc """
  Behaviour defining the layout resolver interface.

  This behaviour abstracts layout resolution and rendering operations,
  allowing the application layer to depend on abstractions rather than
  concrete infrastructure implementations.

  ## Usage

  Infrastructure implementations should implement this behaviour:

      defmodule Alkali.Infrastructure.LayoutResolver do
        @behaviour Alkali.Application.Behaviours.LayoutResolverBehaviour

        @impl true
        def resolve_layout(page, config, opts), do: # implementation
        # ... other implementations
      end

  Use cases should accept the implementation via options:

      def execute(page, opts \\\\ []) do
        layout_resolver = Keyword.get(opts, :layout_resolver, Alkali.Infrastructure.LayoutResolver)
        layout_resolver.resolve_layout(page, config, opts)
      end
  """

  @doc """
  Resolves the layout file path for a given page.

  ## Resolution Priority

  1. If page has `layout` in frontmatter, use `layouts/{layout}.html.heex`
  2. If no layout specified, extract folder from URL and try `layouts/{folder}.html.heex`
  3. If folder-based layout doesn't exist, use `layouts/default.html.heex`
  4. Return error if resolved layout doesn't exist

  ## Returns

    - `{:ok, layout_path}` on success
    - `{:error, reason}` on failure
  """
  @callback resolve_layout(map(), map(), keyword()) :: {:ok, String.t()} | {:error, String.t()}

  @doc """
  Extracts the top-level folder name from a URL.

  Used for folder-based layout resolution.

  ## Examples

      iex> extract_folder_from_url("/posts/2024/my-post")
      "posts"

      iex> extract_folder_from_url("/about")
      "page"
  """
  @callback extract_folder_from_url(String.t()) :: String.t()

  @doc """
  Renders a page with its layout template.

  ## Parameters

    - `page` - Page struct/map with content and metadata
    - `layout_path` - Full path to layout file
    - `config` - Site configuration map
    - `opts` - Additional rendering options

  ## Returns

    - `{:ok, html}` - Rendered HTML string
    - `{:error, reason}` - Error message
  """
  @callback render_with_layout(map(), String.t(), map(), keyword()) ::
              {:ok, String.t()} | {:error, String.t()}
end
