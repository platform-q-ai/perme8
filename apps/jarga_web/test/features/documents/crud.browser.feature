@browser
Feature: Document CRUD Operations
  As a workspace member
  I want to create, update, and delete documents
  So that I can manage my team's documentation

  # Background data setup (workspaces, users, roles) is handled by seed data.
  # Users:
  #   alice@example.com   - owner of workspace "product-team"
  #   bob@example.com     - admin of workspace "product-team"
  #   charlie@example.com - member of workspace "product-team"
  #   diana@example.com   - guest of workspace "product-team"
  #   eve@example.com     - not a member of workspace "product-team"
  #
  # Seeded documents used in this file:
  #   "Draft Roadmap"  - private, owned by alice (slug: draft-roadmap)
  #   "Private Doc"    - private, owned by alice (slug: private-doc)
  #   "Public Doc"     - public, owned by alice (slug: public-doc)
  #   "Valid Title"    - private, owned by alice (slug: valid-title)
  #   "Important Doc"  - private, owned by alice (slug: important-doc)
  #   "Pinned Doc"     - private, owned by alice (slug: pinned-doc)
  #   "Old Doc"        - private, owned by alice (slug: old-doc)

  # ── Document Creation ─────────────────────────────────────────────

  Scenario: Owner creates a document in workspace
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    And I click the "New Document" button
    And I wait for ".modal-open" to be visible
    And I fill "#document-form_title" with "Product Roadmap"
    And I click the "Create Document" button and wait for navigation
    Then the URL should contain "/documents/product-roadmap"
    And I should see "Product Roadmap"

  Scenario: Admin creates a document in workspace
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    And I click the "New Document" button
    And I wait for ".modal-open" to be visible
    And I fill "#document-form_title" with "Architecture Doc"
    And I click the "Create Document" button and wait for navigation
    Then the URL should contain "/documents/"
    And I should see "Architecture Doc"

  Scenario: Member creates a document in workspace
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    And I click the "New Document" button
    And I wait for ".modal-open" to be visible
    And I fill "#document-form_title" with "Meeting Notes"
    And I click the "Create Document" button and wait for navigation
    Then the URL should contain "/documents/"
    And I should see "Meeting Notes"

  Scenario: Guest cannot create documents
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    Then I should not see "New Document"

  Scenario: Document slug handles special characters
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    And I click the "New Document" button
    And I wait for ".modal-open" to be visible
    And I fill "#document-form_title" with "Product & Services (2024)"
    And I click the "Create Document" button and wait for navigation
    Then the URL should contain "/documents/"
    And I should see "Product & Services (2024)"

  # ── Document Title Editing ────────────────────────────────────────

  Scenario: Owner updates document title
    # Precondition: alice owns "Draft Roadmap" (seeded, slug: draft-roadmap)
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/draft-roadmap"
    And I wait for network idle
    And I click "h1"
    And I wait for "#document-title-input" to be visible
    And I clear "#document-title-input"
    And I fill "#document-title-input" with "Product Roadmap Q1"
    And I press "Enter"
    And I wait for network idle
    Then I should see "Product Roadmap Q1"

  Scenario: Empty title is rejected and original title preserved
    # Precondition: alice owns "Valid Title" (seeded, slug: valid-title)
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/valid-title"
    And I wait for network idle
    And I click "h1"
    And I wait for "#document-title-input" to be visible
    And I clear "#document-title-input"
    And I fill "#document-title-input" with ""
    And I press "Enter"
    And I wait for network idle
    Then I should see "Valid Title"

  # ── Document Visibility ───────────────────────────────────────────

  Scenario: Owner makes a private document public
    # Precondition: alice owns private "Private Doc" (seeded, slug: private-doc)
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/private-doc"
    And I wait for network idle
    And I click ".dropdown button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I click the "Make Public" button
    And I wait for network idle
    Then I should see "Document is now shared with workspace members"

  Scenario: Owner makes a public document private
    # Precondition: alice owns public "Public Doc" (seeded, slug: public-doc)
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/public-doc"
    And I wait for network idle
    And I click ".dropdown button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I click the "Make Private" button
    And I wait for network idle
    Then I should see "Document is now private"

  Scenario: Guest cannot access kebab menu
    # Precondition: "Team Guidelines" is a public document (seeded, slug: team-guidelines)
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/team-guidelines"
    And I wait for network idle
    Then I should see "read-only mode"
    And ".dropdown button[aria-label='Actions menu']" should not exist

  # ── Document Pinning ──────────────────────────────────────────────

  Scenario: Owner pins a document
    # Precondition: alice owns unpinned "Important Doc" (seeded, slug: important-doc)
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/important-doc"
    And I wait for network idle
    And I click ".dropdown button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I click the "Pin Document" button
    Then I should see "Document pinned"

  Scenario: Owner unpins a document
    # Precondition: alice owns pinned "Pinned Doc" (seeded, slug: pinned-doc)
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/pinned-doc"
    And I wait for network idle
    And I click ".dropdown button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I click the "Unpin Document" button
    Then I should see "Document unpinned"

  Scenario: Guest cannot pin documents
    # Precondition: "Team Guidelines" is a public document (seeded, slug: team-guidelines)
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/team-guidelines"
    And I wait for network idle
    Then ".dropdown button[aria-label='Actions menu']" should not exist

  # ── Document Deletion ─────────────────────────────────────────────

  Scenario: Owner deletes a document
    # Precondition: alice owns "Old Doc" (seeded, slug: old-doc)
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/old-doc"
    And I wait for network idle
    And I click ".dropdown button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I accept the next browser dialog
    And I click the "Delete Document" button
    And I wait for network idle
    Then the URL should contain "/app/workspaces/${productTeamSlug}"
    And I should see "Document deleted"
    And I should not see "Old Doc"

  Scenario: Guest cannot delete documents
    # Precondition: "Team Guidelines" is a public document (seeded, slug: team-guidelines)
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/team-guidelines"
    And I wait for network idle
    Then ".dropdown button[aria-label='Actions menu']" should not exist
    And I should not see "Delete Document"
