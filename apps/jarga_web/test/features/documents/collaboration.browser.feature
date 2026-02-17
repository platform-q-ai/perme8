@browser
Feature: Document Collaboration
  As a workspace member
  I want to collaborate on documents in real-time
  So that my team can work together efficiently

  # Background data setup (workspaces, users, roles) is handled by seed data.
  # Users:
  #   alice@example.com   - owner of workspace "product-team"
  #   bob@example.com     - admin of workspace "product-team"
  #   charlie@example.com - member of workspace "product-team"
  #   diana@example.com   - guest of workspace "product-team"
  #
  # Seeded documents used in this file:
  #   "Shared Doc"     - public, by bob (slug: shared-doc)
  #   "Product Spec"   - public, by alice (slug: product-spec)
  #   "Collab Pin Doc" - private, by alice (slug: collab-pin-doc)

  # ── Single-user collaborative features ────────────────────────────

  Scenario: User opens document with collaborative editor
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then I should see "Product Spec"
    And "#editor-container" should be visible
    And "#editor-container" should have attribute "data-readonly" with value "false"

  Scenario: Document title can be edited inline
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/shared-doc"
    And I wait for network idle
    Then I should see "Shared Doc"
    When I click "h1"
    And I wait for "#document-title-input" to be visible
    Then "#document-title-input" should be visible

  Scenario: Document visibility toggle works from editor
    # Precondition: bob owns public "Shared Doc" (seeded)
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/shared-doc"
    And I wait for network idle
    And I click ".dropdown button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I click the "Make Private" button
    And I wait for network idle
    Then I should see "Document is now private"

  Scenario: Document pin toggle and listing badge
    # Precondition: alice owns unpinned "Collab Pin Doc" (seeded, slug: collab-pin-doc)
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/collab-pin-doc"
    And I wait for network idle
    And I click ".dropdown button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I click the "Pin Document" button
    Then I should see "Document pinned"
    # Verify pin badge on workspace listing
    When I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    Then I should see "Pinned"

  # ── Multi-user collaboration (requires multiple browsers) ─────────
  #
  # @wip: All multi-user scenarios require two simultaneous browser sessions.
  # The current exo-bdd single-browser runner cannot support this.
  #
  # Migrated from: apps/jarga_web/test/wallaby/document_collaboration_test.exs

  @wip
  Scenario: Two users can edit the same document simultaneously
    # Wallaby: "two users can edit the same document simultaneously"
    # Multi-user: User A types "Hello", User B sees it. User B types " World",
    # both sessions contain both "Hello" and "World".
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO (multi-browser): User B opens same doc in second session
    # TODO (multi-browser): User A types "Hello", User B sees it
    # TODO (multi-browser): User B types " World"
    # TODO (multi-browser): Both editors contain "Hello" and "World"

  @wip
  Scenario: Concurrent edits converge to same state
    # Wallaby: "concurrent edits converge to same state"
    # Multi-user: User A types "Alice's text" and User B types "Bob's text"
    # at the same time. Yjs CRDT ensures both contributions are preserved
    # in both sessions.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO (multi-browser): Both users type concurrently
    # TODO (multi-browser): Both editors contain both contributions (CRDT convergence)

  @wip
  Scenario: Document saves persist after page refresh
    # Wallaby: "document saves persist after page refresh"
    # Single-user: Type content, refresh page, verify content is still there.
    # Auto-save should persist the document before navigation.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO: Type "Persistent content" in .ProseMirror
    # TODO: Refresh the page
    # TODO: Wait for editor to reload
    # TODO: Assert editor contains "Persistent content"

  @wip
  Scenario: Late-joining user receives full document state
    # Wallaby: "late-joining user receives full document state"
    # Multi-user: User A opens document and types content. User B joins later
    # and should see everything User A typed (Yjs state sync on connect).
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO (multi-browser): User A types "Early content from Alice"
    # TODO (multi-browser): User B opens document later
    # TODO (multi-browser): User B's editor contains "Early content from Alice"

  @wip
  Scenario: User sees presence indicators for other collaborators
    # Presence indicators (avatars, names) for connected users in the editor.
    # Requires multiple simultaneous sessions.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO (multi-browser): Both users open document
    # TODO (multi-browser): Presence indicator shows both users
