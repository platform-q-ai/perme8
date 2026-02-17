@browser
Feature: Document Components
  As a workspace member
  I want documents to have embedded components
  So that I can structure content within documents

  # Background data setup (workspaces, users, roles) is handled by seed data.
  # Users:
  #   alice@example.com   - owner of workspace "product-team"
  #   bob@example.com     - admin of workspace "product-team"
  #   charlie@example.com - member of workspace "product-team"
  #   diana@example.com   - guest of workspace "product-team"
  #
  # Seeded documents used in this file:
  #   "Product Spec"  - public, by alice (slug: product-spec)
  #   "Public Doc"    - public, by alice (slug: public-doc)

  Scenario: New document has editor container on creation
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    And I click the "New Document" button
    And I wait for ".modal-open" to be visible
    And I fill "#document-form_title" with "Components Test Doc"
    And I click the "Create Document" button and wait for navigation
    Then the URL should contain "/documents/"
    And I should see "Components Test Doc"
    And "#editor-container" should be visible

  Scenario: Existing document shows editor with note component
    # Precondition: alice owns "Product Spec" with a note (seeded)
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    Then "#editor-container" should be visible
    And "#editor-container" should have attribute "data-readonly" with value "false"

  Scenario: Guest sees editor in read-only mode
    # Precondition: "Team Guidelines" is a public document (seeded, slug: team-guidelines)
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/team-guidelines"
    And I wait for network idle
    Then "#editor-container" should be visible
    And "#editor-container" should have attribute "data-readonly" with value "true"
    And I should see "read-only mode"
