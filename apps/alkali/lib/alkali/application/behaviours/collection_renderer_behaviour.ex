defmodule Alkali.Application.Behaviours.CollectionRendererBehaviour do
  @moduledoc """
  Behaviour for collection page rendering operations.

  Defines the contract for renderers that generate HTML for collection
  pages including post lists, pagination controls, and collection metadata.
  """

  @doc """
  Renders complete collection content with metadata.

  ## Parameters

    - `collection` - Collection struct with type, name, and pages
    - `pagination` - Pagination struct (or nil for non-paginated)
    - `opts` - Rendering options (reserved for future use)

  ## Returns

  A tuple of `{title, content}` where title is the page title
  and content is the HTML string.
  """
  @callback render_collection_content(map(), map() | nil, keyword()) :: {String.t(), String.t()}
end
