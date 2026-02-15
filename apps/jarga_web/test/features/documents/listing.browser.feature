@browser
Feature: Document Listing
  As a workspace member
  I want to see documents filtered by visibility and project
  So that I can find the documents I need

  # Background data setup (workspaces, users, roles, documents) is handled by seed data.
  # Users:
  #   alice@example.com   - owner of workspace "product-team"
  #   bob@example.com     - admin of workspace "product-team"
  #   charlie@example.com - member of workspace "product-team"
  #   diana@example.com   - guest of workspace "product-team"
  #   eve@example.com     - not a member of workspace "product-team"
  #
  # Seeded documents in workspace "product-team":
  #   "Charlie's Private" - owned by charlie, private
  #   "Alice's Private"   - owned by alice, private
  #   "Alice's Public"    - owned by alice, public
  #   "Bob's Public"      - owned by bob, public

  Scenario: User sees their own documents and public documents
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "charlie@example.com"
    And I fill "#login_form_password_password" with "password123"
    And I click the "Log in and stay logged in" button
    And I wait for the page to load
    And I navigate to "${baseUrl}/app/workspaces/product-team"
    And I wait for the page to load
    Then I should see "Charlie's Private"
    And I should see "Alice's Public"
    And I should see "Bob's Public"
    And I should not see "Alice's Private"

  Scenario: Workspace page shows only workspace-level documents (not project documents)
    # Precondition: seeded workspace docs and project docs
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "alice@example.com"
    And I fill "#login_form_password_password" with "password123"
    And I click the "Log in and stay logged in" button
    And I wait for the page to load
    And I navigate to "${baseUrl}/app/workspaces/product-team"
    And I wait for the page to load
    Then I should see "Workspace Doc"
    And I should not see "Project Doc"

  Scenario: List documents filtered by project
    # Precondition: seeded projects "Mobile App" and "Web App" with documents
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "alice@example.com"
    And I fill "#login_form_password_password" with "password123"
    And I click the "Log in and stay logged in" button
    And I wait for the page to load
    And I navigate to "${baseUrl}/app/workspaces/product-team/projects/mobile-app"
    And I wait for the page to load
    Then I should see "Mobile Specs"
    And I should see "Mobile Design"
    And I should not see "Web Architecture"
