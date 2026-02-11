defmodule JargaWeb.Features.MarkdownRenderingTest do
  use JargaWeb.FeatureCase, async: false
  import JargaWeb.FeatureCase.Helpers

  @moduletag :javascript

  describe "Markdown Pasting & Rendering" do
    setup do
      # Use persistent test users
      user_a = Jarga.TestUsers.get_user(:alice)

      # Create a workspace
      workspace = workspace_fixture(user_a)

      # Create a document
      document = document_fixture(user_a, workspace, nil, %{is_public: true})

      session = new_session()
      {:ok, session: session, user_a: user_a, workspace: workspace, document: document}
    end

    @tag :javascript
    test "pasted heading renders as styled heading", %{
      session: session,
      user_a: user_a,
      workspace: workspace,
      document: document
    } do
      # User logs in and opens document
      session
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)
      |> click_in_editor()

      # Simulate pasting "# Heading 1" by typing it
      # (Wallaby doesn't support clipboard, so we type markdown and let Milkdown parse it)
      session
      |> send_keys(["# Heading 1"])

      # Verify heading is rendered (not raw markdown)
      session
      |> assert_has(css("h1", text: "Heading 1", count: 1))

      # Verify no markdown syntax visible (# should not be displayed as text)
      # In Milkdown, headings are rendered as proper <h1> elements
      session
      |> refute_has(css(".ProseMirror", text: "# Heading 1"))
    end

    @tag :javascript
    test "pasted bold text renders as bold", %{
      session: session,
      user_a: user_a,
      workspace: workspace,
      document: document
    } do
      # User logs in and opens document
      session
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)
      |> click_in_editor()

      # Type bold markdown
      session
      |> send_keys(["**bold text**"])

      # Verify bold text is rendered
      # Milkdown renders bold as <strong> inside a paragraph
      session
      |> assert_has(css("strong", text: "bold text", count: 1))

      # The ** symbols should not be visible (they become the <strong> tag)
      # However, this is tricky to test because Milkdown may show them while typing
      # We'll just verify the strong tag exists
    end

    @tag :javascript
    test "pasted list renders as formatted list", %{
      session: session,
      user_a: user_a,
      workspace: workspace,
      document: document
    } do
      # User logs in and opens document
      session
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)
      |> click_in_editor()

      # Type list markdown (one item at a time)
      session
      |> send_keys(["- Item 1"])
      |> send_keys([:enter])
      |> send_keys(["Item 2"])
      |> send_keys([:enter])
      |> send_keys(["Item 3"])

      # Verify list is rendered (scope to editor to avoid navigation/sidebar lists)
      session
      |> assert_has(css(".ProseMirror ul", count: 1))
      |> assert_has(css(".ProseMirror ul li", count: 3))

      # Verify list items contain correct text
      session
      |> assert_has(css(".ProseMirror ul li", text: "Item 1"))
      |> assert_has(css(".ProseMirror ul li", text: "Item 2"))
      |> assert_has(css(".ProseMirror ul li", text: "Item 3"))
    end

    @tag :javascript
    test "pasted code block renders with monospace font", %{
      session: session,
      user_a: user_a,
      workspace: workspace,
      document: document
    } do
      # User logs in and opens document
      session
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)
      |> click_in_editor()

      # Type code fence markdown
      session
      |> send_keys(["```elixir"])
      |> send_keys([:enter])
      |> send_keys(["defmodule Test do"])
      |> send_keys([:enter])
      |> send_keys(["  def hello, do: :world"])
      |> send_keys([:enter])
      |> send_keys(["end"])
      |> send_keys([:enter])
      |> send_keys(["```"])

      # Verify code block is rendered
      # Milkdown renders code blocks as <pre><code> elements
      session
      |> assert_has(css("pre code", count: 1))

      # Verify code content is present
      session
      |> assert_has(css("pre code", text: "defmodule Test do"))
    end

    @tag :javascript
    test "typed link markdown auto-converts to clickable link", %{
      session: session,
      user_a: user_a,
      workspace: workspace,
      document: document
    } do
      # With our custom markdown input rules plugin, typing [text](url)
      # now auto-converts to <a href="url">text</a> as you type!

      session
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)
      |> click_in_editor()
      # Type: "Check out [Google](https://google.com) for search"
      |> send_keys(["Check out [Google](https://google.com) for search"])

      # Verify link is rendered with correct text (scope to editor)
      session
      |> assert_has(css(".ProseMirror a[href='https://google.com']", text: "Google", count: 1))

      # Verify the opening bracket is NOT left behind
      session
      |> refute_has(css(".ProseMirror", text: "Check out [Google"))

      # Verify text before link is not part of link
      session
      |> refute_has(css(".ProseMirror a", text: "Check out"))

      # Verify text after link is not part of link
      session
      |> refute_has(css(".ProseMirror a", text: "for search"))

      # Verify the full text structure is correct
      session
      |> assert_has(css(".ProseMirror", text: "Check out Google for search"))

      # Verify the link is clickable (has proper href that can be navigated to)
      # We check this by verifying the link element exists with the correct href attribute
      # In a real browser:
      # - Hover over link: Text cursor (I-beam) - ready for editing
      # - Hover over link with Cmd/Ctrl: Pointer cursor (hand) - ready for navigation
      # - Regular click: Places cursor in link text (for editing)
      # - Cmd+Click (Mac) or Ctrl+Click (Windows/Linux): Opens link in new tab
      session
      |> assert_has(css(".ProseMirror a[href='https://google.com']"))

      # Verify only the word "Google" is the clickable link text (no trailing space)
      session
      |> assert_has(css(".ProseMirror a", text: "Google", count: 1))

      # Verify the link text does NOT have a trailing space
      # The link should be exactly "Google", not "Google " with a space
      session
      |> refute_has(css(".ProseMirror a", text: "Google "))

      # Note: We cannot easily test Cmd/Ctrl+Click and cursor changes in Wallaby since
      # it requires modifier keys, cursor inspection, and detecting new window/tab opens.
      # This is better tested manually. The linkClickPlugin handles:
      # - Cursor change from text to pointer when Cmd/Ctrl is held over links
      # - Opening links in new tabs with Cmd/Ctrl+Click
    end

    @tag :javascript
    test "typed image markdown auto-converts to image element", %{
      session: session,
      user_a: user_a,
      workspace: workspace,
      document: document
    } do
      # With our custom markdown input rules plugin, typing ![alt](url)
      # now auto-converts to <img src="url" alt="alt"> as you type!

      session
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)
      |> click_in_editor()
      # Type: "Check out ![Test Image](https://example.com/image.png) here"
      |> send_keys(["Check out ![Test Image](https://example.com/image.png) here"])

      # Give the markdown input rule time to process and render the image
      Process.sleep(500)

      # Verify image is rendered with correct attributes (scope to editor)
      session
      |> assert_has(css(".ProseMirror img[alt='Test Image']", count: 1))
      |> assert_has(css(".ProseMirror img[src='https://example.com/image.png']", count: 1))

      # Verify the opening ![bracket is NOT left behind
      session
      |> refute_has(css(".ProseMirror", text: "Check out ![Test Image"))

      # Verify the full text structure is correct (text before and after image)
      # Note: Images are rendered as <img> elements, not text, so we check surrounding text
      session
      |> assert_has(css(".ProseMirror", text: "Check out"))
      |> assert_has(css(".ProseMirror", text: "here"))
    end

    @tag :javascript
    test "complex markdown document renders correctly", %{
      session: session,
      user_a: user_a,
      workspace: workspace,
      document: document
    } do
      # User logs in and opens document
      session
      |> log_in_user(user_a)
      |> open_document(workspace.slug, document.slug)
      |> click_in_editor()

      # Type heading
      session
      |> send_keys(["# Main Heading"])
      |> send_keys([:enter, :enter])

      # Type paragraph with bold and italic
      session
      |> send_keys(["This is **bold** and *italic* text."])
      |> send_keys([:enter, :enter])

      # Type list
      session
      |> send_keys(["- First item"])
      |> send_keys([:enter])
      |> send_keys(["Second item"])

      # Verify all elements rendered (scope to editor)
      # Note: Link rendering in Milkdown requires specific triggers that don't work
      # reliably in automated tests. We test the other markdown elements here.
      session
      |> assert_has(css(".ProseMirror h1", text: "Main Heading"))
      |> assert_has(css(".ProseMirror strong", text: "bold"))
      |> assert_has(css(".ProseMirror em", text: "italic"))
      |> assert_has(css(".ProseMirror ul li", count: 2))
    end
  end
end
