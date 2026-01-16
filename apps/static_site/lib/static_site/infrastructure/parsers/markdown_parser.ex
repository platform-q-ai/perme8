defmodule StaticSite.Infrastructure.Parsers.MarkdownParser do
  @moduledoc """
  Markdown parser with basic HTML conversion.
  """

  @doc """
  Parses markdown to HTML with GFM extensions.
  """
  @spec parse(String.t()) :: String.t()
  def parse(""), do: ""

  def parse(markdown) do
    blocks = String.split(markdown, "\n\n", trim: true)

    Enum.map_join(blocks, "", fn block ->
      lines = String.split(block, "\n")

      if special_block?(lines) do
        process_special_block(lines)
      else
        processed = process_inline(List.first(lines))
        "<p>#{processed}</p>"
      end
    end)
  end

  defp special_block?(["```" <> _ | _]), do: true
  defp special_block?(["| " <> _ | _]), do: true
  defp special_block?(["* " <> _ | _]), do: true
  defp special_block?(["- [x] " <> _ | _]), do: true
  defp special_block?(["- [ ] " <> _ | _]), do: true
  defp special_block?(["- " <> _ | _]), do: true
  defp special_block?(["# " <> _ | _]), do: true
  defp special_block?(["## " <> _ | _]), do: true
  defp special_block?(["### " <> _ | _]), do: true
  defp special_block?(["[x] " <> _ | _]), do: true
  defp special_block?(["[ ] " <> _ | _]), do: true
  defp special_block?(["**" <> _]), do: false
  defp special_block?(["[" <> _]), do: false
  defp special_block?(["![" <> _]), do: false
  defp special_block?(["`" <> _]), do: false
  defp special_block?(["~~" <> _]), do: false
  defp special_block?(["*<" <> _]), do: false
  defp special_block?([">" <> _]), do: false
  defp special_block?(_), do: false

  defp process_special_block(["```" <> lang | lines]) do
    code =
      lines
      |> Enum.drop_while(&(&1 == "```"))
      |> Enum.take_while(&(&1 != "```"))
      |> Enum.join("\n")

    lang = String.trim(lang)
    "<pre><code class=\"language-#{lang}\">#{code}</code></pre>"
  end

  defp process_special_block(["> " <> text | _]) do
    "<blockquote>#{process_inline(text)}</blockquote>"
  end

  defp process_special_block(lines = ["| " <> _ | _]) do
    rows =
      Enum.map(lines, fn line ->
        cells = String.split(line, "|", trim: true) |> Enum.map(&String.trim/1)
        Enum.map_join(cells, "", &"<td>#{&1}</td>")
      end)

    "<table>#{Enum.map_join(rows, "", &"<tr>#{&1}</tr>")}</table>"
  end

  defp process_special_block(["# " <> text | _]), do: "<h1>#{process_inline(text)}</h1>"
  defp process_special_block(["## " <> text | _]), do: "<h2>#{process_inline(text)}</h2>"
  defp process_special_block(["### " <> text | _]), do: "<h3>#{process_inline(text)}</h3>"

  defp process_special_block(lines) do
    # Must be a list
    case List.first(lines) do
      "* " <> _ -> process_list(lines)
      "- " <> _ -> process_list(lines)
      "[x] " <> _ -> process_list(lines)
      "[ ] " <> _ -> process_list(lines)
      _ -> ""
    end
  end

  defp process_list(lines) do
    items =
      Enum.map(lines, fn
        # Put more specific patterns first
        "- [x] " <> text -> "<li><input type=\"checkbox\" checked> #{process_inline(text)}</li>"
        "- [ ] " <> text -> "<li><input type=\"checkbox\"> #{process_inline(text)}</li>"
        "- " <> text -> "<li>#{process_inline(text)}</li>"
        "* " <> text -> "<li>#{process_inline(text)}</li>"
        "[x] " <> text -> "<li><input type=\"checkbox\" checked> #{process_inline(text)}</li>"
        "[ ] " <> text -> "<li><input type=\"checkbox\"> #{process_inline(text)}</li>"
        _ -> ""
      end)

    "<ul>#{Enum.join(items)}</ul>"
  end

  defp process_inline(text) do
    text
    |> String.replace(~r/\*\*(.+?)\*\*/, "<strong>\\1</strong>")
    |> String.replace(~r/\*(.+?)\*/, "<em>\\1</em>")
    |> String.replace(~r/`(.+?)`/, "<code>\\1</code>")
    |> String.replace(~r/~~(.+?)~~/, "<del>\\1</del>")
    |> String.replace(~r/\[([^\]]+)\]\(([^)]+)\)/, "<a href=\"\\2\">\\1</a>")
  end
end
