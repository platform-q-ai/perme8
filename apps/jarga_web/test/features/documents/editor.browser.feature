@browser
Feature: Document Editor
  As a workspace member
  I want to use the document editor to create and modify content
  So that I can collaborate on documentation

  # Background data setup (workspaces, users, roles) is handled by seed data.
  # Users:
  #   alice@example.com   - owner of workspace "product-team"
  #   bob@example.com     - admin of workspace "product-team"
  #   charlie@example.com - member of workspace "product-team"
  #   diana@example.com   - guest of workspace "product-team"
  #
  # Seeded documents used in this file:
  #   "Product Spec"   - public, owned by alice (slug: product-spec)
  #   "Public Doc"     - public, owned by alice (slug: public-doc)
  #   "Team Guidelines"- public, owned by alice (slug: team-guidelines)

  Scenario: Editor container loads for document owner
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

  Scenario: Editor is writable for members on public documents
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/team-guidelines"
    And I wait for network idle
    Then I should see "Team Guidelines"
    And "#editor-container" should be visible
    And "#editor-container" should have attribute "data-readonly" with value "false"
    And I should not see "read-only mode"

  Scenario: Editor is read-only for guests
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/public-doc"
    And I wait for network idle
    Then I should see "Public Doc"
    And I should see "read-only mode"
    And "#editor-container" should have attribute "data-readonly" with value "true"

  Scenario: Title is editable by clicking the h1
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    And I click "h1"
    And I wait for "#document-title-input" to be visible
    Then "#document-title-input" should be visible

  Scenario: Guest cannot click title to edit
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/public-doc"
    And I wait for network idle
    And I click "h1"
    And I wait for 1 seconds
    Then "#document-title-input" should not exist

  Scenario: Editor container has Milkdown hook
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/documents/product-spec"
    And I wait for network idle
    And I wait for "#editor-container" to be visible
    Then "#editor-container" should exist
