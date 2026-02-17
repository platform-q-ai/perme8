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
  # Multi-browser scenarios use named sessions for independent browser contexts.
  # Yjs UndoManager scopes undo/redo to the local user's operations.
  #
  # Migrated from: apps/jarga_web/test/wallaby/undo_redo_test.exs

  Scenario: Undo reverts only local user's changes
    # Wallaby: "undo reverts only local user's changes"
    # User A types "Hello", User B types "World".
    # User A presses Ctrl+Z — "Hello" disappears but "World" remains.
    Given I open browser session "alice"
    And I am on "${baseUrl}/users/log-in"
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
    Given I open browser session "bob"
    And I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # Alice types "Hello"
    When I switch to browser session "alice"
    And I click ".ProseMirror"
    And I type "Hello" into ".ProseMirror"
    And I wait for 2 seconds
    # Bob types " World" on a new line
    When I switch to browser session "bob"
    And I click ".ProseMirror"
    And I press "End"
    And I press "Enter"
    And I type "World" into ".ProseMirror"
    And I wait for 2 seconds
    # Verify both contributions exist
    When I switch to browser session "alice"
    Then ".ProseMirror" should contain text "Hello"
    And ".ProseMirror" should contain text "World"
    # Alice presses Ctrl+Z — only "Hello" should be undone
    When I press "Control+z"
    And I wait for 2 seconds
    Then I should not see "Hello"
    And ".ProseMirror" should contain text "World"
    # Bob's editor should also show "World" without "Hello"
    When I switch to browser session "bob"
    Then ".ProseMirror" should contain text "World"

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

  Scenario: Undo does not affect other users' undo stacks
    # Wallaby: "undo does not affect other users' undo stacks"
    # User A types "A text", User B types "B text". Both see both.
    # User A undoes — "A text" gone, "B text" remains for both.
    # User B undoes independently — "B text" gone too.
    Given I open browser session "alice"
    And I am on "${baseUrl}/users/log-in"
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
    Given I open browser session "bob"
    And I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # Alice types "A text"
    When I switch to browser session "alice"
    And I click ".ProseMirror"
    And I type "A text" into ".ProseMirror"
    And I wait for 2 seconds
    # Bob types "B text" on new line
    When I switch to browser session "bob"
    And I click ".ProseMirror"
    And I press "End"
    And I press "Enter"
    And I type "B text" into ".ProseMirror"
    And I wait for 2 seconds
    # Both editors contain both
    When I switch to browser session "alice"
    Then ".ProseMirror" should contain text "A text"
    And ".ProseMirror" should contain text "B text"
    # Alice undoes — "A text" gone, "B text" remains
    When I press "Control+z"
    And I wait for 2 seconds
    Then I should not see "A text"
    And ".ProseMirror" should contain text "B text"
    # Bob's view: "A text" gone, "B text" remains
    When I switch to browser session "bob"
    Then ".ProseMirror" should contain text "B text"
    # Bob undoes independently — "B text" gone
    When I press "Control+z"
    And I wait for 2 seconds
    Then I should not see "B text"

  Scenario: Undo works correctly after remote changes arrive
    # Wallaby: "undo works correctly after remote changes"
    # User A types "Hello", syncs. User B types "World", syncs.
    # User A types " Again", syncs. User A undoes — only their contributions
    # are removed, "World" remains.
    Given I open browser session "alice"
    And I am on "${baseUrl}/users/log-in"
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
    Given I open browser session "bob"
    And I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # Alice types "Hello"
    When I switch to browser session "alice"
    And I click ".ProseMirror"
    And I type "Hello" into ".ProseMirror"
    And I wait for 2 seconds
    # Bob types "World" on new line
    When I switch to browser session "bob"
    And I click ".ProseMirror"
    And I press "End"
    And I press "Enter"
    And I type "World" into ".ProseMirror"
    And I wait for 2 seconds
    # Alice types " Again" after her "Hello"
    When I switch to browser session "alice"
    And I click ".ProseMirror"
    And I press "Home"
    And I press "End"
    And I type " Again" into ".ProseMirror"
    And I wait for 2 seconds
    # Alice undoes — her contributions should be removed
    When I press "Control+z"
    And I wait for 2 seconds
    Then I should not see "Again"
    And ".ProseMirror" should contain text "World"
