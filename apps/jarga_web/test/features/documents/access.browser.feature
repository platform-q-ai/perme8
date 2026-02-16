@browser
Feature: Document Access Control
  As a workspace member
  I want document visibility and permissions to be enforced
  So that private documents remain confidential

  # Background data setup (workspaces, users, roles) is handled by seed data.
  # Users:
  #   alice@example.com   - owner of workspace "product-team"
  #   bob@example.com     - admin of workspace "product-team"
  #   charlie@example.com - member of workspace "product-team"
  #   diana@example.com   - guest of workspace "product-team"
  #   eve@example.com     - not a member of workspace "product-team"
  #
  # Seeded documents used in this file:
  #   "Private Notes"          - private, owned by alice (slug: private-notes)
  #   "Alices Private Notes"   - private, owned by alice (slug: alices-private-notes)
  #   "Team Guidelines"        - public, owned by alice (slug: team-guidelines)
  #   "Private Roadmap"        - private, owned by alice (slug: private-roadmap)
  #   "Specs"                  - public, project: mobile-app (slug: specs)

  # ── Document Viewing ──────────────────────────────────────────────

  Scenario: Owner views their own private document
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/private-notes"
    And I wait for the page to load
    Then I should see "Private Notes"
    And "#editor-container" should be visible
    And I should not see "read-only mode"

  Scenario: Member cannot view another user's private document
    # alice owns "Alices Private Notes" which is private
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/alices-private-notes"
    And I wait for the page to load
    Then I should see "Document not found"

  Scenario: Admin cannot view another user's private document
    # alice owns "Alices Private Notes" which is private
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/alices-private-notes"
    And I wait for the page to load
    Then I should see "Document not found"

  Scenario: Member views public document created by another user
    # alice owns "Team Guidelines" which is public
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/team-guidelines"
    And I wait for the page to load
    Then I should see "Team Guidelines"
    And "#editor-container" should be visible
    And I should not see "read-only mode"

  Scenario: Guest views public document in read-only mode
    # alice owns "Team Guidelines" which is public
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/team-guidelines"
    And I wait for the page to load
    Then I should see "Team Guidelines"
    And I should see "read-only mode"
    And "#editor-container" should have attribute "data-readonly" with value "true"

  Scenario: Guest cannot view private documents
    # alice owns "Private Roadmap" which is private
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/private-roadmap"
    And I wait for the page to load
    Then I should see "Document not found"

  Scenario: Non-member cannot view any workspace documents
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${nonMemberEmail}"
    And I fill "#login_form_password_password" with "${nonMemberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/team-guidelines"
    And I wait for the page to load
    Then I should not see "Team Guidelines"

  # ── Breadcrumb Navigation ─────────────────────────────────────────

  Scenario: Document in a project shows breadcrumb context
    # "Specs" belongs to project "Mobile App" in workspace "product-team"
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/specs"
    And I wait for the page to load
    Then I should see "Specs"
