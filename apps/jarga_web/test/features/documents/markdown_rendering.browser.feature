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
  # The Milkdown editor uses ProseMirror input rules to convert markdown syntax
  # into rich text as you type. Each character is typed sequentially via
  # pressSequentially, triggering input rules (e.g., "# " becomes <h1>).
  #
  # IMPORTANT: Each scenario clears the editor (Ctrl+A, Backspace) before typing
  # because Yjs document state persists between scenarios on the same document.
  #
  # Migrated from: apps/jarga_web/test/wallaby/markdown_rendering_test.exs

  Scenario: Heading markdown renders as styled heading
    # Wallaby: "pasted heading renders as styled heading"
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    When I click ".ProseMirror"
    And I press "Control+a"
    And I press "Backspace"
    And I type "# Heading 1" into ".ProseMirror"
    Then ".ProseMirror h1" should exist
    And ".ProseMirror h1" should contain text "Heading 1"

  Scenario: Bold markdown renders as bold text
    # Wallaby: "pasted bold text renders as bold"
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    When I click ".ProseMirror"
    And I press "Control+a"
    And I press "Backspace"
    And I type "some **bold text** here" into ".ProseMirror"
    Then ".ProseMirror strong" should exist
    And ".ProseMirror strong" should contain text "bold text"

  Scenario: List markdown renders as formatted list
    # Wallaby: "pasted list renders as formatted list"
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    When I click ".ProseMirror"
    And I press "Control+a"
    And I press "Backspace"
    And I type "- Item 1" into ".ProseMirror"
    And I press "Enter"
    And I type "Item 2" into ".ProseMirror"
    And I press "Enter"
    And I type "Item 3" into ".ProseMirror"
    Then ".ProseMirror ul" should exist
    And there should be 3 ".ProseMirror ul li" elements

  Scenario: Code fence markdown renders as code block
    # Wallaby: "pasted code block renders with monospace font"
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    When I click ".ProseMirror"
    And I press "Control+a"
    And I press "Backspace"
    And I type "```elixir" into ".ProseMirror"
    And I press "Enter"
    And I type "defmodule Test do" into ".ProseMirror"
    Then ".ProseMirror pre" should exist
    And ".ProseMirror pre" should contain text "defmodule Test do"

  Scenario: Link markdown auto-converts to clickable link
    # Wallaby: "typed link markdown auto-converts to clickable link"
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    When I click ".ProseMirror"
    And I press "Control+a"
    And I press "Backspace"
    And I type "Check out [Google](https://google.com) for search" into ".ProseMirror"
    Then ".ProseMirror a[href='https://google.com']" should exist
    And ".ProseMirror a" should contain text "Google"

  Scenario: Image markdown auto-converts to image element
    # Wallaby: "typed image markdown auto-converts to image element"
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    When I click ".ProseMirror"
    And I press "Control+a"
    And I press "Backspace"
    And I type "![Test Image](https://example.com/image.png) " into ".ProseMirror"
    Then ".ProseMirror img[src='https://example.com/image.png']" should exist

  Scenario: Complex markdown document renders all element types
    # Wallaby: "complex markdown document renders correctly"
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    When I click ".ProseMirror"
    And I press "Control+a"
    And I press "Backspace"
    And I type "# Main Heading" into ".ProseMirror"
    And I press "Enter"
    And I type "This is **bold** and *italic* text." into ".ProseMirror"
    And I press "Enter"
    And I type "- First item" into ".ProseMirror"
    And I press "Enter"
    And I type "Second item" into ".ProseMirror"
    Then ".ProseMirror h1" should exist
    And ".ProseMirror strong" should exist
    And ".ProseMirror em" should exist
    And there should be 2 ".ProseMirror ul li" elements
