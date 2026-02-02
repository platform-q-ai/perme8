defmodule Alkali.Application.Behaviours.FrontmatterParserBehaviour do
  @moduledoc """
  Behaviour for frontmatter parsing operations.

  Defines the contract for parsers that extract YAML metadata
  from markdown files.
  """

  @doc """
  Extracts frontmatter YAML and content from a markdown file.

  ## Parameters

    - `content` - The raw file content string

  ## Returns

    - `{:ok, {frontmatter_map, content_string}}` on success
    - `{:error, reason}` on parsing failure
  """
  @callback parse(String.t()) :: {:ok, {map(), String.t()}} | {:error, String.t()}
end
