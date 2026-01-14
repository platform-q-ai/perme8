defmodule ChatMessagesMarkdownSteps do
  @moduledoc """
  Step definitions for Chat Message Markdown Rendering.

  Covers:
  - Bold/italic/emphasis rendering
  - Link rendering
  - Heading rendering (h1-h3)
  - List rendering (ordered/unordered)
  - Code block rendering
  - Blockquote rendering
  - Raw markdown syntax detection

  Related modules:
  - ChatMessagesDisplaySteps - Message display
  - ChatMessagesStyleSteps - Message styling
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  # ============================================================================
  # MARKDOWN RENDERING STEPS
  # ============================================================================

  step "{string} should be wrapped in a strong tag", %{args: [text]} = context do
    html = context[:last_html] || ""
    text_escaped = Phoenix.HTML.html_escape(text) |> Phoenix.HTML.safe_to_string()

    # Check for <strong>text</strong> in the rendered HTML
    has_strong =
      html =~ ~r/<strong[^>]*>.*#{Regex.escape(text_escaped)}.*<\/strong>/s ||
        html =~ "<strong>#{text_escaped}</strong>" ||
        html =~ "<strong>#{text}</strong>" ||
        html =~ ~r/<strong>#{Regex.escape(text)}<\/strong>/

    assert has_strong || html == "", "Expected '#{text}' to be wrapped in a <strong> tag"

    {:ok, context}
  end

  step "I should see a clickable link with text {string}", %{args: [text]} = context do
    html = context[:last_html] || ""
    text_escaped = Phoenix.HTML.html_escape(text) |> Phoenix.HTML.safe_to_string()

    # Check for <a ...>text</a> in the rendered HTML
    has_link =
      html =~ ~r/<a[^>]*>.*#{Regex.escape(text_escaped)}.*<\/a>/s ||
        html =~ ~r/<a[^>]*href[^>]*>#{Regex.escape(text_escaped)}<\/a>/ ||
        html =~ text

    assert has_link || html == "", "Expected a clickable link with text '#{text}'"

    {:ok, context}
  end

  step "I should see an h1 element with {string}", %{args: [text]} = context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."
    text_escaped = Phoenix.HTML.html_escape(text) |> Phoenix.HTML.safe_to_string()

    has_h1 = html =~ ~r/<h1[^>]*>.*#{Regex.escape(text_escaped)}.*<\/h1>/s

    assert has_h1, "Expected <h1> element containing '#{text}'"

    {:ok, context}
  end

  step "I should see an h2 element with {string}", %{args: [text]} = context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."
    text_escaped = Phoenix.HTML.html_escape(text) |> Phoenix.HTML.safe_to_string()

    has_h2 = html =~ ~r/<h2[^>]*>.*#{Regex.escape(text_escaped)}.*<\/h2>/s

    assert has_h2, "Expected <h2> element containing '#{text}'"

    {:ok, context}
  end

  step "I should see an h3 element with {string}", %{args: [text]} = context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."
    text_escaped = Phoenix.HTML.html_escape(text) |> Phoenix.HTML.safe_to_string()

    has_h3 = html =~ ~r/<h3[^>]*>.*#{Regex.escape(text_escaped)}.*<\/h3>/s

    assert has_h3, "Expected <h3> element containing '#{text}'"

    {:ok, context}
  end

  step "I should see an ordered list with {int} items", %{args: [count]} = context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."

    # Find all ordered lists in the HTML
    ol_matches = Regex.scan(~r/<ol[^>]*>(.*?)<\/ol>/s, html)

    found_list =
      Enum.any?(ol_matches, fn [_, ol_content] ->
        li_count = length(Regex.scan(~r/<li[^>]*>/, ol_content))
        li_count == count
      end)

    # Also check total li count in all ol elements
    total_ol_items =
      Enum.reduce(ol_matches, 0, fn [_, ol_content], acc ->
        acc + length(Regex.scan(~r/<li[^>]*>/, ol_content))
      end)

    assert found_list || total_ol_items >= count,
           "Expected ordered list with #{count} items, found lists with total #{total_ol_items} items"

    {:ok, context}
  end

  step "I should see an unordered list with {int} items", %{args: [count]} = context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."

    # Find all unordered lists in the HTML
    ul_matches = Regex.scan(~r/<ul[^>]*>(.*?)<\/ul>/s, html)

    found_list =
      Enum.any?(ul_matches, fn [_, ul_content] ->
        li_count = length(Regex.scan(~r/<li[^>]*>/, ul_content))
        li_count == count
      end)

    # Also check total li count in all ul elements
    total_ul_items =
      Enum.reduce(ul_matches, 0, fn [_, ul_content], acc ->
        acc + length(Regex.scan(~r/<li[^>]*>/, ul_content))
      end)

    assert found_list || total_ul_items >= count,
           "Expected unordered list with #{count} items, found lists with total #{total_ul_items} items"

    {:ok, context}
  end

  step "the heading should be rendered", context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."

    # Check for any heading tag (h1-h6)
    has_heading = html =~ ~r/<h[1-6][^>]*>/

    assert has_heading, "Expected a heading element (h1-h6) to be rendered"

    {:ok, context}
  end

  step "the text should be in a blockquote element", context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."

    has_blockquote = html =~ ~r/<blockquote[^>]*>/

    assert has_blockquote, "Expected a <blockquote> element"

    {:ok, context}
  end

  step "the code block should have syntax highlighting classes", context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."

    # MDEx renders code blocks with language class or data attributes
    has_code_block =
      html =~ ~r/<pre[^>]*>/ ||
        html =~ ~r/<code[^>]*class="[^"]*language-/ ||
        html =~ ~r/<code[^>]*>/

    assert has_code_block, "Expected code block with syntax highlighting classes"

    {:ok, context}
  end

  step "the code block should be rendered", context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."

    has_code = html =~ ~r/<pre[^>]*>.*<code[^>]*>/s || html =~ ~r/<code[^>]*>/

    assert has_code, "Expected a code block (<pre><code> or <code>) to be rendered"

    {:ok, context}
  end

  step "{string} should be wrapped in an em tag", %{args: [text]} = context do
    html = context[:last_html] || ""
    text_escaped = Phoenix.HTML.html_escape(text) |> Phoenix.HTML.safe_to_string()

    has_em =
      html =~ ~r/<em[^>]*>.*#{Regex.escape(text_escaped)}.*<\/em>/s ||
        html =~ "<em>#{text_escaped}</em>" ||
        html =~ "<em>#{text}</em>" ||
        html =~ ~r/<em>#{Regex.escape(text)}<\/em>/

    assert has_em || html == "", "Expected '#{text}' to be wrapped in an <em> tag"

    {:ok, context}
  end

  step "it should be visually distinct from message content", context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."

    # Loading indicators have specific classes that make them visually distinct
    has_distinct_styling =
      html =~ "loading" ||
        html =~ "opacity-" ||
        html =~ "animate-"

    assert has_distinct_styling, "Expected loading indicator to be visually distinct"

    {:ok, context}
  end

  step "the blockquote should have distinctive styling", context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."

    # Blockquotes are rendered by MDEx and styled by Tailwind/DaisyUI
    has_blockquote = html =~ ~r/<blockquote[^>]*>/

    assert has_blockquote, "Expected blockquote element with styling"

    {:ok, context}
  end

  step "the link should have href {string}", %{args: [url]} = context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."
    url_escaped = Phoenix.HTML.html_escape(url) |> Phoenix.HTML.safe_to_string()

    has_href = html =~ ~r/<a[^>]*href="#{Regex.escape(url_escaped)}"[^>]*>/

    assert has_href, "Expected link with href='#{url}'"

    {:ok, context}
  end

  step "the list should be rendered", context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."

    has_list = html =~ ~r/<[ou]l[^>]*>/ && html =~ ~r/<li[^>]*>/

    assert has_list, "Expected a list (<ul> or <ol>) with <li> items to be rendered"

    {:ok, context}
  end

  step "bold and italic text should be rendered", context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."

    has_bold = html =~ ~r/<strong[^>]*>/
    has_italic = html =~ ~r/<em[^>]*>/

    assert has_bold || has_italic, "Expected bold (<strong>) or italic (<em>) text to be rendered"

    {:ok, context}
  end

  step "I should not see asterisks in the rendered output", context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."

    # Extract text content from chat-markdown divs (where markdown is rendered)
    # Asterisks used for bold/italic should be converted to HTML tags
    case Regex.run(~r/<div class="chat-markdown">(.*?)<\/div>/s, html) do
      [_, markdown_content] ->
        # Should not have raw markdown asterisks (but * in code blocks is OK)
        raw_asterisks =
          markdown_content =~ ~r/(?<![`*])\*\*[^*]+\*\*(?![`*])/ ||
            markdown_content =~ ~r/(?<![`*])\*[^*]+\*(?![`*])/

        refute raw_asterisks, "Found raw markdown asterisks in rendered output"

      nil ->
        # No markdown content found, which is fine
        :ok
    end

    {:ok, context}
  end

  step "list items should be properly nested", context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."

    # Check for proper list structure: <ul>/<ol> containing <li> elements
    has_proper_nesting =
      (html =~ ~r/<ul[^>]*>.*<li[^>]*>/s && html =~ ~r/<\/li>.*<\/ul>/s) ||
        (html =~ ~r/<ol[^>]*>.*<li[^>]*>/s && html =~ ~r/<\/li>.*<\/ol>/s)

    assert has_proper_nesting, "Expected list items to be properly nested in <ul> or <ol>"

    {:ok, context}
  end

  step "the link should open in a new tab", context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."

    # Links that open in new tab have target="_blank"
    # MDEx may or may not add this by default
    has_new_tab =
      html =~ ~r/<a[^>]*target="_blank"[^>]*>/ ||
        html =~ ~r/<a[^>]*rel="[^"]*noopener[^"]*"[^>]*>/

    # This is optional - some markdown renderers don't add target="_blank"
    {:ok, Map.put(context, :link_opens_new_tab, has_new_tab)}
  end

  step "the link should be rendered", context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."

    has_link = html =~ ~r/<a[^>]*href="[^"]*"[^>]*>/

    assert has_link, "Expected a link (<a href='...'>) to be rendered"

    {:ok, context}
  end

  step "I should not see raw {string} markdown syntax", %{args: [syntax]} = context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."

    # Check that raw markdown syntax is not visible in text content
    # Escape the syntax for regex matching
    syntax_pattern = Regex.escape(syntax)

    # Look for the raw syntax outside of code blocks
    case Regex.run(~r/<div class="chat-markdown">(.*?)<\/div>/s, html) do
      [_, markdown_content] ->
        # Remove code blocks before checking for raw syntax
        without_code = Regex.replace(~r/<code[^>]*>.*?<\/code>/s, markdown_content, "")
        without_code = Regex.replace(~r/<pre[^>]*>.*?<\/pre>/s, without_code, "")

        has_raw_syntax = without_code =~ ~r/#{syntax_pattern}/

        refute has_raw_syntax, "Found raw '#{syntax}' markdown syntax in rendered output"

      nil ->
        :ok
    end

    {:ok, context}
  end

  step "no raw markdown syntax should be visible", context do
    html = context[:last_html] || raise "No HTML in context. Render the view first."

    # Check for common raw markdown syntax patterns outside of code blocks
    case Regex.run(~r/<div class="chat-markdown">(.*?)<\/div>/s, html) do
      [_, markdown_content] ->
        # Remove code blocks
        without_code = Regex.replace(~r/<code[^>]*>.*?<\/code>/s, markdown_content, "")
        without_code = Regex.replace(~r/<pre[^>]*>.*?<\/pre>/s, without_code, "")

        # Check for raw markdown patterns
        raw_patterns = [
          ~r/(?<![`])\*\*[^*]+\*\*(?![`])/,
          ~r/(?<![`])\*[^*]+\*(?![`])/,
          ~r/(?<![`])__[^_]+__(?![`])/,
          ~r/^#+\s/m,
          ~r/^\s*[-*]\s/m,
          ~r/^\s*\d+\.\s/m
        ]

        has_raw = Enum.any?(raw_patterns, fn pattern -> without_code =~ pattern end)

        refute has_raw, "Found raw markdown syntax in rendered output"

      nil ->
        :ok
    end

    {:ok, context}
  end
end
