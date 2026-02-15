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

  # Document Viewing

  Scenario: Owner views their own private document
    # Precondition: alice owns a private document "Private Notes" (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for the page to load
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/private-notes"
    And I wait for the page to load
    Then I should see "Private Notes"
    And "#editor-container" should be visible
    And I should not see "read-only mode"

  Scenario: Member cannot view another user's private document
    # Precondition: alice owns a private document "Alice's Private Notes" (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for the page to load
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/alices-private-notes"
    And I wait for the page to load
    Then I should see "Document not found"
    And the URL should contain "/app/workspaces"

  Scenario: Admin cannot view another user's private document
    # Precondition: alice owns a private document "Alice's Private Notes" (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for the page to load
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/alices-private-notes"
    And I wait for the page to load
    Then I should see "Document not found"
    And the URL should contain "/app/workspaces"

  Scenario: Member views public document created by another user
    # Precondition: alice owns a public document "Team Guidelines" (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for the page to load
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/team-guidelines"
    And I wait for the page to load
    Then I should see "Team Guidelines"
    And "#editor-container" should be visible
    And I should not see "read-only mode"

  Scenario: Guest views public document in read-only mode
    # Precondition: alice owns a public document "Team Guidelines" (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for the page to load
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/team-guidelines"
    And I wait for the page to load
    Then I should see "Team Guidelines"
    And I should see "read-only mode"
    And "#editor-container" should have attribute "data-readonly" with value "true"

  Scenario: Guest cannot view private documents
    # Precondition: alice owns a private document "Private Roadmap" (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for the page to load
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/private-roadmap"
    And I wait for the page to load
    Then I should see "Document not found"
    And the URL should contain "/app/workspaces"

  Scenario: Non-member cannot view any documents
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${nonMemberEmail}"
    And I fill "#login_form_password_password" with "${nonMemberPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for the page to load
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/team-guidelines"
    And I wait for the page to load
    Then the URL should contain "/app/workspaces"
    And I should not see "Team Guidelines"

  # Breadcrumb Navigation

  Scenario: Breadcrumb navigation in document view
    # Precondition: alice owns a document "Specs" in project "Mobile App" (seeded)
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for the page to load
    And I navigate to "${baseUrl}/app/workspaces/product-team/documents/specs"
    And I wait for the page to load
    Then I should see "Product Team"
    And I should see "Mobile App"
    And I should see "Specs"
