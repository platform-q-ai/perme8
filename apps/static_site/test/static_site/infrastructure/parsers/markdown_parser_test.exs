defmodule StaticSite.Infrastructure.Parsers.MarkdownParserTest do
  use ExUnit.Case, async: true

  alias StaticSite.Infrastructure.Parsers.MarkdownParser

  describe "parse/1" do
    test "converts markdown to HTML" do
      markdown = "# Hello World\n\nThis is a paragraph."
      result = MarkdownParser.parse(markdown)
      assert result =~ ~r/<h1.*>Hello World<\/h1>/
      assert result =~ ~r/<p.*>This is a paragraph.<\/p>/
    end

    test "handles GFM extensions like tables" do
      markdown = """
      | Header 1 | Header 2 |
      |----------|----------|
      | Cell 1   | Cell 2   |
      """

      result = MarkdownParser.parse(markdown)
      assert result =~ "<table"
      assert result =~ "Header 1"
      assert result =~ "Cell 1"
    end

    test "handles GFM extensions like strikethrough" do
      markdown = "~~strikethrough~~"
      result = MarkdownParser.parse(markdown)
      assert result =~ "<del"
      assert result =~ "strikethrough"
    end

    test "handles GFM extensions like task lists" do
      markdown = """
      - [x] Done
      - [ ] Not done
      """

      result = MarkdownParser.parse(markdown)
      assert result =~ "type=\"checkbox\""
      assert result =~ "checked"
    end

    test "handles code blocks" do
      markdown = """
      ```elixir
      defmodule Test do
        def hello, do: "world"
      end
      ```
      """

      result = MarkdownParser.parse(markdown)
      assert result =~ "<pre"
      assert result =~ "defmodule"
    end

    test "handles empty markdown" do
      result = MarkdownParser.parse("")
      assert is_binary(result)
    end

    test "handles markdown with HTML" do
      markdown = "Text with <strong>bold</strong> HTML"
      result = MarkdownParser.parse(markdown)
      assert result =~ "Text with <strong>bold</strong> HTML"
    end
  end
end
