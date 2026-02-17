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

  # ── Multi-user collaboration (multiple browser sessions) ──────────
  #
  # Multi-browser scenarios use named sessions: "I open browser session {name}"
  # creates a separate BrowserContext+Page with independent cookies/localStorage.
  # "I switch to browser session {name}" changes which session receives commands.
  #
  # Migrated from: apps/jarga_web/test/wallaby/document_collaboration_test.exs

  Scenario: Two users can edit the same document simultaneously
    # Wallaby: "two users can edit the same document simultaneously"
    # Session "alice": owner logs in and opens document
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
    # Session "bob": admin logs in and opens same document
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
    # Bob should see "Hello" via Yjs sync
    When I switch to browser session "bob"
    Then ".ProseMirror" should contain text "Hello"
    # Bob types " World"
    When I click ".ProseMirror"
    And I press "End"
    And I type " World" into ".ProseMirror"
    And I wait for 2 seconds
    # Both sessions should contain both contributions
    Then ".ProseMirror" should contain text "Hello"
    And ".ProseMirror" should contain text "World"
    When I switch to browser session "alice"
    Then ".ProseMirror" should contain text "Hello"
    And ".ProseMirror" should contain text "World"

  Scenario: Concurrent edits converge to same state
    # Wallaby: "concurrent edits converge to same state"
    # Both users type content; Yjs CRDT ensures both contributions are preserved.
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
    # Alice types her content
    When I switch to browser session "alice"
    And I click ".ProseMirror"
    And I type "Alice was here" into ".ProseMirror"
    # Bob types his content (on same line or new paragraph)
    When I switch to browser session "bob"
    And I click ".ProseMirror"
    And I press "End"
    And I press "Enter"
    And I type "Bob was here" into ".ProseMirror"
    And I wait for 2 seconds
    # Both sessions should contain both contributions (CRDT convergence)
    Then ".ProseMirror" should contain text "Alice was here"
    And ".ProseMirror" should contain text "Bob was here"
    When I switch to browser session "alice"
    Then ".ProseMirror" should contain text "Alice was here"
    And ".ProseMirror" should contain text "Bob was here"

  Scenario: Document saves persist after page refresh
    # Wallaby: "document saves persist after page refresh"
    # Single-user: Type content, wait for auto-save, refresh page, verify content.
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
    And I type "Persistent content after refresh" into ".ProseMirror"
    And I wait for 2 seconds
    And I reload the page
    And I wait for network idle
    Then "#editor-container" should be visible
    And ".ProseMirror" should contain text "Persistent content after refresh"

  Scenario: Late-joining user receives full document state
    # Wallaby: "late-joining user receives full document state"
    # User A opens document and types content. User B joins later
    # and should see everything User A typed (Yjs state sync on connect).
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
    And I type "Early content from Alice" into ".ProseMirror"
    And I wait for 2 seconds
    # Bob joins later — should receive full state via Yjs sync
    Given I open browser session "bob"
    And I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    And ".ProseMirror" should contain text "Early content from Alice"

  @wip
  Scenario: User sees presence indicators for other collaborators
    # Presence indicators (avatars, names) for connected users in the editor.
    # @wip: Presence UI not yet implemented in the editor.
    Given I open browser session "alice"
    And I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    # TODO: Assert presence indicator shows Alice
    Given I open browser session "bob"
    And I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    # TODO: Assert presence indicator shows both Alice and Bob
