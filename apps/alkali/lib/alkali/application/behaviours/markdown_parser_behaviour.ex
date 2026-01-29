defmodule Alkali.Application.Behaviours.MarkdownParserBehaviour do
  @moduledoc """
  Behaviour for markdown parsing operations.

  Defines the contract for parsers that convert markdown
  content to HTML.
  """

  @doc """
  Parses markdown content to HTML.

  ## Parameters

    - `markdown` - The markdown string to parse

  ## Returns

  An HTML string representation of the markdown content.
  """
  @callback parse(String.t()) :: String.t()
end
