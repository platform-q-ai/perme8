defmodule Alkali.Infrastructure.Parsers.FrontmatterParserTest do
  use ExUnit.Case, async: true

  alias Alkali.Infrastructure.Parsers.FrontmatterParser

  describe "parse/1" do
    test "extracts frontmatter and content" do
      input = """
      ---
      title: "My Post"
      date: "2024-01-01"
      draft: false
      ---

      This is the content.
      """

      result = FrontmatterParser.parse(input)

      assert {:ok, {frontmatter, content}} = result
      assert frontmatter["title"] == "My Post"
      assert frontmatter["date"] == "2024-01-01"
      assert frontmatter["draft"] == false
      assert content == "This is the content.\n"
    end

    test "handles missing frontmatter" do
      input = "Just regular content"

      result = FrontmatterParser.parse(input)

      assert {:ok, {%{}, "Just regular content"}} = result
    end

    test "handles frontmatter with arrays" do
      input = """
      ---
      tags: [elixir, phoenix, web]
      title: "Test"
      ---

      Content
      """

      result = FrontmatterParser.parse(input)

      assert {:ok, {frontmatter, _content}} = result
      assert frontmatter["tags"] == ["elixir", "phoenix", "web"]
      assert frontmatter["title"] == "Test"
    end

    test "handles frontmatter with nested objects" do
      input = """
      ---
      metadata:
        author: "John"
        category: "tech"
      title: "Nested"
      ---

      Content
      """

      result = FrontmatterParser.parse(input)

      assert {:ok, {frontmatter, _content}} = result
      assert frontmatter["metadata"]["author"] == "John"
      assert frontmatter["metadata"]["category"] == "tech"
    end

    test "handles multiple dashes in delimiters" do
      input = """
      ---
      title: "Three Dashes"
      ---

      Content
      """

      result = FrontmatterParser.parse(input)

      assert {:ok, {_frontmatter, _content}} = result
    end

    test "returns error for invalid YAML" do
      input = """
      ---
      title: "Unclosed quote
      ---

      Content
      """

      assert {:error, _reason} = FrontmatterParser.parse(input)
    end

    test "handles content-only with just dashes" do
      input = """
      ---

      Content after dashes
      """

      result = FrontmatterParser.parse(input)

      assert {:ok, {%{}, "Content after dashes\n"}} = result
    end
  end
end
