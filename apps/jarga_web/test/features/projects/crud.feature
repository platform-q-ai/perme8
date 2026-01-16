Feature: Project CRUD Operations
  As a workspace member
  I want to create, update, and delete projects
  So that I can organize documents within my workspace

Background:
  Given a workspace exists with name "Product Team" and slug "product-team"
  And a user "alice@example.com" exists as owner of workspace "product-team"
  And a user "bob@example.com" exists as admin of workspace "product-team"
  And a user "charlie@example.com" exists as member of workspace "product-team"
  And a user "diana@example.com" exists as guest of workspace "product-team"
  And a user "eve@example.com" exists but is not a member of workspace "product-team"


  # Project Creation

  Scenario: Owner creates a project in workspace
    Given I am logged in as "alice@example.com"
    And I list projects in workspace "product-team"
    When I create a project with name "Mobile App" in workspace "product-team"
    Then the project should be created successfully
    And the project should have slug "mobile-app"
    And the project should be owned by "alice@example.com"
    And a project created notification should be broadcast

  Scenario: Admin creates a project in workspace
    Given I am logged in as "bob@example.com"
    When I create a project with name "Backend Services" in workspace "product-team"
    Then the project should be created successfully
    And the project should be owned by "bob@example.com"

  Scenario: Member creates a project in workspace
    Given I am logged in as "charlie@example.com"
    When I create a project with name "Documentation" in workspace "product-team"
    Then the project should be created successfully
    And the project should be owned by "charlie@example.com"

  Scenario: Guest cannot create projects
    Given I am logged in as "diana@example.com"
    When I attempt to create a project with name "Unauthorized Project" in workspace "product-team"
    Then I should receive a forbidden error

  Scenario: Non-member cannot create projects
    Given I am logged in as "eve@example.com"
    When I attempt to create a project with name "Outsider Project" in workspace "product-team"
    Then I should receive an unauthorized error

  Scenario: Create project with full details
    Given I am logged in as "alice@example.com"
    When I create a project with the following details in workspace "product-team":
      | name        | description                  | color   |
      | Web App     | Our main web application     | #3B82F6 |
    Then the project should be created successfully
    And the project name should be "Web App"
    And the project description should be "Our main web application"
    And the project color should be "#3B82F6"

  Scenario: Project slug is unique within workspace
    Given I am logged in as "alice@example.com"
    And a project exists with name "Mobile App" in workspace "product-team"
    When I create a project with name "Mobile App" in workspace "product-team"
    Then the project should be created successfully
    And the project should have a unique slug like "mobile-app-*"

  Scenario: Project slug is generated from name
    Given I am logged in as "alice@example.com"
    When I create a project with name "Product & Services (2024)" in workspace "product-team"
    Then the project should be created successfully
    And the project slug should be URL-safe

  Scenario: Create project with empty or missing name
    Given I am logged in as "alice@example.com"
    When I attempt to create a project with name "" in workspace "product-team"
    Then I should receive a validation error
    And the project should not be created

  Scenario: Project slug handles special characters
    Given I am logged in as "alice@example.com"
    When I create a project with name "R&D: AI/ML (Phase 2)" in workspace "product-team"
    Then the project should be created successfully
    And the project slug should be URL-safe
    And the project slug should not contain special characters

  # Project Updates

  Scenario: Owner updates their own project name
    Given I am logged in as "alice@example.com"
    And a project exists with name "Draft Project" owned by "alice@example.com"
    And I am viewing the project
    When I update the project name to "Mobile Application"
    Then the project name should be "Mobile Application"
    And a project updated notification should be broadcast

  Scenario: Owner updates project description
    Given I am logged in as "alice@example.com"
    And a project exists with name "Mobile App" owned by "alice@example.com"
    When I update the project description to "iOS and Android applications"
    Then the project description should be "iOS and Android applications"

  Scenario: Owner updates project color
    Given I am logged in as "alice@example.com"
    And a project exists with name "Mobile App" owned by "alice@example.com"
    When I update the project color to "#10B981"
    Then the project color should be "#10B981"

  Scenario: Admin can update any project
    Given I am logged in as "bob@example.com"
    And a project exists with name "Charlie's Project" owned by "charlie@example.com"
    When I update the project name to "Team Project"
    Then the project name should be "Team Project"

  Scenario: Member can only update their own projects
    Given I am logged in as "charlie@example.com"
    And a project exists with name "Alice's Project" owned by "alice@example.com"
    And a project exists with name "Charlie's Project" owned by "charlie@example.com"
    When I attempt to update "Alice's Project" name to "Hacked Project"
    Then I should receive a forbidden error
    When I update "Charlie's Project" name to "My Updated Project"
    Then the project "Charlie's Project" name should be "My Updated Project"

  Scenario: Guest cannot update any projects
    Given I am logged in as "diana@example.com"
    And a project exists with name "Mobile App" owned by "alice@example.com"
    When I attempt to update the project name to "Guest Edit"
    Then I should receive a forbidden error

  Scenario: Update project with empty name
    Given I am logged in as "alice@example.com"
    And a project exists with name "Valid Project" owned by "alice@example.com"
    When I attempt to update the project name to ""
    Then I should receive a validation error
    And the project name should remain "Valid Project"

  # Project Deletion

  Scenario: Owner deletes their own project
    Given I am logged in as "alice@example.com"
    And a project exists with name "Temporary Project" owned by "alice@example.com"
    And I am viewing the project
    When I delete the project
    Then the project should be deleted successfully
    And a project deleted notification should be broadcast

  Scenario: Admin can delete any project
    Given I am logged in as "bob@example.com"
    And a project exists with name "Outdated Project" owned by "charlie@example.com"
    When I delete the project
    Then the project should be deleted successfully

  Scenario: Member can only delete their own projects
    Given I am logged in as "charlie@example.com"
    And a project exists with name "Alice's Project" owned by "alice@example.com"
    And a project exists with name "Charlie's Project" owned by "charlie@example.com"
    When I attempt to delete project "Alice's Project"
    Then I should receive a forbidden error
    When I delete project "Charlie's Project"
    Then the project should be deleted successfully

  Scenario: Guest cannot delete any projects
    Given I am logged in as "diana@example.com"
    And a project exists with name "Mobile App" owned by "alice@example.com"
    When I attempt to delete the project
    Then I should receive a forbidden error

  Scenario: Non-member cannot delete projects
    Given I am logged in as "eve@example.com"
    When I attempt to delete a project in workspace "product-team"
    Then I should receive an unauthorized error

  Scenario: Deleting project does not delete documents
    Given I am logged in as "alice@example.com"
    And a project exists with name "Temporary" owned by "alice@example.com"
    And a document exists with title "Important Doc" in project "Temporary"
    When I delete the project
    Then the project should be deleted successfully
    And the document "Important Doc" should still exist
    And the document should no longer be associated with a project
