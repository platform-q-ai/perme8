@browser
Feature: Undo/Redo in Collaborative Editor
  As a document collaborator
  I want undo and redo to only affect my own changes
  So that I can safely revert mistakes without disrupting other users' work

  # Background data setup (workspaces, users, roles) is handled by seed data.
  # Users:
  #   alice@example.com - owner of workspace "product-team"
  #   bob@example.com   - admin of workspace "product-team"
  #
  # Seeded documents used in this file:
  #   "Product Spec" - public, by alice (slug: product-spec)
  #
  # @wip: Multi-user scenarios require two simultaneous browser sessions.
  #
  # Migrated from: apps/jarga_web/test/wallaby/undo_redo_test.exs

  @wip
  Scenario: Undo reverts only local user's changes
    # Wallaby: "undo reverts only local user's changes"
    # Multi-user: User A types "Hello", User B types "World".
    # User A presses Ctrl+Z — "Hello" disappears but "World" remains.
    # Yjs scoped undo only reverts the local user's operations.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO (multi-browser): User A types "Hello", User B types "World"
    # TODO (multi-browser): User A presses Ctrl+Z
    # TODO (multi-browser): User A's editor does NOT contain "Hello" but contains "World"
    # TODO (multi-browser): User B's editor still contains "World"

  Scenario: Redo re-applies local user's undone changes
    # Wallaby: "redo re-applies local user's undone changes"
    # Single-user: Type "Hello", Ctrl+Z (gone), Ctrl+Shift+Z (back).
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
    And I type "Hello" into ".ProseMirror"
    Then ".ProseMirror" should contain text "Hello"
    When I press "Control+z"
    Then I should not see "Hello"
    When I press "Control+Shift+z"
    Then ".ProseMirror" should contain text "Hello"

  @wip
  Scenario: Undo does not affect other users' undo stacks
    # Wallaby: "undo does not affect other users' undo stacks"
    # Multi-user: User A types "A", User B types "B". Both see "A" and "B".
    # User A undoes — "A" gone, "B" remains for both.
    # User B undoes independently — "B" gone too.
    # Each user's undo stack is independent (Yjs UndoManager).
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO (multi-browser): User A types "A", User B types "B"
    # TODO (multi-browser): Both editors contain "A" and "B"
    # TODO (multi-browser): User A presses Ctrl+Z — "A" gone, "B" remains (both users)
    # TODO (multi-browser): User B presses Ctrl+Z — "B" gone (independent stack)

  @wip
  Scenario: Undo works correctly after remote changes arrive
    # Wallaby: "undo works correctly after remote changes"
    # Multi-user: User A types "Hello", syncs. User B types "World", syncs.
    # User A types "!", syncs. User A undoes — their entire contribution
    # ("Hello!") is removed, only "World" remains. Yjs batches rapid
    # same-user operations into a single undo step.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO (multi-browser): User A types "Hello", wait for sync
    # TODO (multi-browser): User B types "World", wait for sync
    # TODO (multi-browser): User A types "!", wait for sync
    # TODO (multi-browser): Both editors contain "Hello", "World", "!"
    # TODO (multi-browser): User A presses Ctrl+Z
    # TODO (multi-browser): Both editors: no "Hello", no "!", only "World" remains
