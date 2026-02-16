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

  # Collaborative Editing

  Scenario: User opens document with collaborative editor
    # Precondition: alice owns a public document "Collaborative Doc" (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "alice@example.com"
    And I fill "#login_form_password_password" with "password123"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/collaborative-doc"
    And I wait for the page to load
    Then I should see "Collaborative Doc"
    And "#editor-container" should be visible
    And "#editor-container" should have attribute "data-readonly" with value "false"

  Scenario: User can edit document content
    # Precondition: alice owns a document "My Notes" (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "alice@example.com"
    And I fill "#login_form_password_password" with "password123"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/my-notes"
    And I wait for the page to load
    Then "#editor-container" should be visible
    And "#editor-container" should have attribute "data-readonly" with value "false"
    When I click "#editor-container"
    Then "#editor-container" should be visible

  # Real-time Notifications

  Scenario: Document title is visible and editable
    # Precondition: alice owns a public document "Team Doc" (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "alice@example.com"
    And I fill "#login_form_password_password" with "password123"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/team-doc"
    And I wait for the page to load
    Then I should see "Team Doc"
    When I click "h1"
    And I wait for "#document-title-input" to be visible
    And I clear "#document-title-input"
    And I fill "#document-title-input" with "Updated Team Doc"
    And I press "Enter"
    And I wait for network idle
    Then I should see "Updated Team Doc"

  Scenario: Document visibility can be toggled
    # Precondition: alice owns a public document "Shared Doc" (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "alice@example.com"
    And I fill "#login_form_password_password" with "password123"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/shared-doc"
    And I wait for the page to load
    And I click ".kebab-menu button"
    And I click the "Make Private" button
    And I wait for network idle
    Then I should see "Document is now private"

  Scenario: Document pin status can be toggled
    # Precondition: alice owns a public document "Important Doc" (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "alice@example.com"
    And I fill "#login_form_password_password" with "password123"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/important-doc"
    And I wait for the page to load
    And I click ".kebab-menu button"
    And I click the "Pin Document" button
    And I wait for network idle
    Then I should see "Document pinned"
    # Verify pin shows on workspace listing
    When I navigate to "${baseUrl}/app/workspaces/product-team"
    And I wait for the page to load
    Then I should see "Pinned"
