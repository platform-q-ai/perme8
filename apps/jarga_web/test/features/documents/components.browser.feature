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

  Scenario: Document has embedded note component by default
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "alice@example.com"
    And I fill "#login_form_password_password" with "password123"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team"
    And I wait for the page to load
    And I click the "New Document" button
    And I wait for ".modal-open" to be visible
    And I fill "[name='title']" with "New Doc"
    And I click the "Create Document" button
    And I wait for the page to load
    Then the URL should contain "/documents/"
    And I should see "New Doc"
    And "#editor-container" should be visible

  Scenario: Access document's embedded note
    # Precondition: alice owns a document "My Doc" with an embedded note (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "alice@example.com"
    And I fill "#login_form_password_password" with "password123"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/my-doc"
    And I wait for the page to load
    Then "#editor-container" should be visible
    And "#editor-container" should have attribute "data-readonly" with value "false"
