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
  #   "Important Doc"  - private, by alice (slug: important-doc)

  # ── Single-user collaborative features ────────────────────────────

  Scenario: User opens document with collaborative editor
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for the page to load
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
    And I wait for the page to load
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
    And I wait for the page to load
    And I click ".dropdown button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I click the "Make Private" button
    And I wait for network idle
    Then I should see "Document is now private"

  Scenario: Document pin toggle and listing badge
    # Precondition: alice owns unpinned "Important Doc" (seeded)
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/important-doc"
    And I wait for the page to load
    And I click ".dropdown button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I click the "Pin Document" button
    And I wait for network idle
    Then I should see "Document pinned"
    # Verify pin badge on workspace listing
    When I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should see "Pinned"

  # ── Multi-user collaboration (requires multiple browsers) ─────────

  @wip
  Scenario: Two users see each other's edits in real-time
    # @wip: Real-time collaboration testing requires two simultaneous browser
    # sessions, which is not supported by the current single-browser test runner.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for the page to load
    Then "#editor-container" should be visible

  @wip
  Scenario: User sees presence indicators for other collaborators
    # @wip: Presence indicators require multiple simultaneous sessions.
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for the page to load
    Then "#editor-container" should be visible
