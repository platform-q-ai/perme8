@browser
Feature: Markdown Rendering in Editor
  As a document author
  I want markdown syntax to render as rich text in the Milkdown editor
  So that I can create formatted documents without switching to a preview mode

  # Background data setup (workspaces, users, roles) is handled by seed data.
  # Users:
  #   alice@example.com - owner of workspace "product-team"
  #
  # Seeded documents used in this file:
  #   "Product Spec" - public, by alice (slug: product-spec)
  #
  # @wip: All scenarios require typing into a ProseMirror/Milkdown contenteditable
  # div and verifying rendered DOM output. The current exo-bdd browser adapter
  # does not yet have step definitions for rich editor interaction (type in editor,
  # assert rendered element inside .ProseMirror, etc.).
  #
  # Migrated from: apps/jarga_web/test/wallaby/markdown_rendering_test.exs

  @wip
  Scenario: Heading markdown renders as styled heading
    # Wallaby: "pasted heading renders as styled heading"
    # Type "# Heading 1" in the editor; verify <h1> element appears
    # and raw "# " syntax is not visible as text.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO: Type "# Heading 1" in .ProseMirror
    # TODO: Assert .ProseMirror h1 contains "Heading 1"
    # TODO: Assert .ProseMirror does NOT contain text "# Heading 1"

  @wip
  Scenario: Bold markdown renders as bold text
    # Wallaby: "pasted bold text renders as bold"
    # Type "**bold text**" in editor; verify <strong> element appears.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO: Type "**bold text**" in .ProseMirror
    # TODO: Assert .ProseMirror strong contains "bold text"

  @wip
  Scenario: List markdown renders as formatted list
    # Wallaby: "pasted list renders as formatted list"
    # Type "- Item 1", Enter, "Item 2", Enter, "Item 3";
    # verify <ul> with 3 <li> elements appears.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO: Type "- Item 1" then Enter, "Item 2" then Enter, "Item 3"
    # TODO: Assert .ProseMirror ul exists with 3 li children
    # TODO: Assert li text matches "Item 1", "Item 2", "Item 3"

  @wip
  Scenario: Code fence markdown renders as code block
    # Wallaby: "pasted code block renders with monospace font"
    # Type "```elixir", Enter, code lines, Enter, "```";
    # verify <pre><code> element appears with code content.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO: Type code fence with elixir content
    # TODO: Assert pre code element contains "defmodule Test do"

  @wip
  Scenario: Link markdown auto-converts to clickable link
    # Wallaby: "typed link markdown auto-converts to clickable link"
    # Type "[Google](https://google.com)"; verify <a href="..."> element
    # appears with correct text, no leftover bracket syntax.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO: Type "Check out [Google](https://google.com) for search"
    # TODO: Assert .ProseMirror a[href='https://google.com'] with text "Google"
    # TODO: Assert no "[Google" text visible (bracket consumed by input rule)
    # TODO: Assert surrounding text "Check out" and "for search" not inside link

  @wip
  Scenario: Image markdown auto-converts to image element
    # Wallaby: "typed image markdown auto-converts to image element"
    # Type "![Alt](url)"; verify <img> element with correct src and alt.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO: Type "![Test Image](https://example.com/image.png)"
    # TODO: Assert .ProseMirror img[alt='Test Image'][src='https://example.com/image.png']
    # TODO: Assert no "![" bracket text visible

  @wip
  Scenario: Complex markdown document renders all element types
    # Wallaby: "complex markdown document renders correctly"
    # Type heading, bold, italic, and list items in sequence;
    # verify h1, strong, em, and ul/li elements all render.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO: Type "# Main Heading" then blank line
    # TODO: Type "This is **bold** and *italic* text." then blank line
    # TODO: Type "- First item" then Enter, "Second item"
    # TODO: Assert h1 "Main Heading", strong "bold", em "italic", 2 li elements
