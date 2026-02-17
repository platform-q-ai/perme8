@browser
Feature: Multiple Cursors in Collaborative Editor
  As a document collaborator
  I want to see other users' cursors in real-time
  So that I know where my teammates are editing

  # Background data setup (workspaces, users, roles) is handled by seed data.
  # Users:
  #   alice@example.com - owner of workspace "product-team"
  #   bob@example.com   - admin of workspace "product-team"
  #
  # Seeded documents used in this file:
  #   "Product Spec" - public, by alice (slug: product-spec)
  #
  # @wip: All scenarios require two simultaneous browser sessions (Yjs awareness)
  # and verifying ProseMirror decoration elements for remote cursors.
  # The current exo-bdd single-browser runner cannot support multi-user tests.
  #
  # Migrated from: apps/jarga_web/test/wallaby/multiple_cursors_test.exs

  @wip
  Scenario: User cursors are visible to other users
    # Wallaby: "user cursors are visible to other users"
    # Multi-user: Both users open the same document and click in the editor
    # to initialize Yjs awareness. User A types text, updating their cursor
    # position. User B should see User A's cursor decoration (label "Alice")
    # in the ProseMirror editor.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO (multi-browser): User A and User B both open the document
    # TODO (multi-browser): Both click in editor to initialize awareness
    # TODO (multi-browser): User A types "Hello from Alice"
    # TODO (multi-browser): User B sees cursor decoration labeled "Alice"

  @wip
  Scenario: Cursor positions update in real-time as users type
    # Wallaby: "cursor positions update in real-time as users type"
    # Multi-user: User A types on line 1, User B sees cursor.
    # User A types on line 2 (cursor moves), User B still sees cursor
    # at updated position.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO (multi-browser): Both users open document and initialize awareness
    # TODO (multi-browser): User A types "Line 1", User B sees cursor
    # TODO (multi-browser): User A types newline + "Line 2" (cursor moves)
    # TODO (multi-browser): User B still sees cursor (at new position)

  @wip
  Scenario: Cursor disappears when user disconnects
    # Wallaby: "cursor disappears when user disconnects"
    # Multi-user: Both users in document, User A types to establish cursor.
    # User B sees User A's cursor. User A disconnects (close browser).
    # User B should see the cursor disappear (Yjs awareness cleanup).
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO (multi-browser): Both users open document, User A types text
    # TODO (multi-browser): User B sees User A's cursor labeled "Alice"
    # TODO (multi-browser): User A disconnects (close session)
    # TODO (multi-browser): User B no longer sees "Alice" cursor (awareness cleanup)

  @wip
  Scenario: Multiple users see each other's cursors simultaneously
    # Wallaby: "multiple users see each other's cursors simultaneously"
    # Multi-user: Both users type in the same document. Each user should
    # see the other's cursor decoration. User A sees "Bob" cursor,
    # User B sees "Alice" cursor — both visible at the same time.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO (multi-browser): Both users open document and initialize awareness
    # TODO (multi-browser): User A types "Alice is typing"
    # TODO (multi-browser): User B types "Bob is also typing"
    # TODO (multi-browser): User A sees cursor labeled "Bob"
    # TODO (multi-browser): User B sees cursor labeled "Alice"
