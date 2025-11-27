Feature: Project Management
  As a workspace member
  I want to create, view, edit, and manage projects
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

  # Project Listing

  Scenario: List all projects in workspace
    Given I am logged in as "alice@example.com"
    And the following projects exist in workspace "product-team":
      | name          | owner             |
      | Mobile App    | alice@example.com |
      | Web App       | bob@example.com   |
    When I list projects in workspace "product-team"
    Then I should see projects:
      | name          |
      | Mobile App    |
      | Web App       |

  Scenario: Guest can view projects in workspace
    Given I am logged in as "diana@example.com"
    And a project exists with name "Public Project" in workspace "product-team"
    When I list projects in workspace "product-team"
    Then I should see "Public Project"

  Scenario: Non-member cannot list projects
    Given I am logged in as "eve@example.com"
    When I attempt to list projects in workspace "product-team"
    Then I should receive a not found error

  # Edge Cases

  Scenario: Create project with empty or missing name
    Given I am logged in as "alice@example.com"
    When I attempt to create a project with name "" in workspace "product-team"
    Then I should receive a validation error
    And the project should not be created

  Scenario: Update project with empty name
    Given I am logged in as "alice@example.com"
    And a project exists with name "Valid Project" owned by "alice@example.com"
    When I attempt to update the project name to ""
    Then I should receive a validation error
    And the project name should remain "Valid Project"

  Scenario: Project slug handles special characters
    Given I am logged in as "alice@example.com"
    When I create a project with name "R&D: AI/ML (Phase 2)" in workspace "product-team"
    Then the project should be created successfully
    And the project slug should be URL-safe
    And the project slug should not contain special characters

  # Real-time Notifications

  Scenario: Project creation notification to workspace members
    Given I am logged in as "alice@example.com"
    And user "charlie@example.com" is viewing workspace "product-team"
    When I create a project with name "New Project" in workspace "product-team"
    Then user "charlie@example.com" should receive a project created notification
    And the new project should appear in their workspace view

  Scenario: Project update notification to workspace members
    Given I am logged in as "alice@example.com"
    And a project exists with name "Mobile App" owned by "alice@example.com"
    And user "charlie@example.com" is viewing workspace "product-team"
    When I update the project name to "Mobile Application"
    Then user "charlie@example.com" should receive a project updated notification
    And the project name should update in their UI without refresh

  Scenario: Project deletion notification to workspace members
    Given I am logged in as "alice@example.com"
    And a project exists with name "Old Project" owned by "alice@example.com"
    And user "charlie@example.com" is viewing workspace "product-team"
    When I delete the project
    Then user "charlie@example.com" should receive a project deleted notification
    And the project should be removed from their workspace view

  # Workspace Integration

  Scenario: Projects are scoped to workspace
    Given I am logged in as "alice@example.com"
    And a workspace exists with name "Marketing Team" and slug "marketing-team"
    And user "alice@example.com" is owner of workspace "marketing-team"
    And a project exists with name "Campaign" in workspace "marketing-team"
    When I list projects in workspace "product-team"
    Then I should not see "Campaign"

  Scenario: Workspace name updates in project view
    Given I am logged in as "alice@example.com"
    And a project exists with name "Mobile App" owned by "alice@example.com"
    And I am viewing the project
    When user "alice@example.com" updates workspace name to "Engineering Team"
    Then I should see the workspace name updated to "Engineering Team" in breadcrumbs

  Scenario: Breadcrumb navigation in project view
    Given I am logged in as "alice@example.com"
    And a project exists with name "Mobile App" in workspace "product-team"
    When I view the project
    Then I should see breadcrumbs showing "Product Team > Mobile App"

  # Document Association

  Scenario: Project contains associated documents
    Given I am logged in as "alice@example.com"
    And a project exists with name "Mobile App" in workspace "product-team"
    And the following documents exist in project "Mobile App":
      | title           |
      | Architecture    |
      | Requirements    |
      | Design Specs    |
    When I view project "Mobile App"
    Then I should see 3 documents in the project
    And the project should contain documents:
      | title           |
      | Architecture    |
      | Requirements    |
      | Design Specs    |

  Scenario: Deleting project does not delete documents
    Given I am logged in as "alice@example.com"
    And a project exists with name "Temporary" owned by "alice@example.com"
    And a document exists with title "Important Doc" in project "Temporary"
    When I delete the project
    Then the project should be deleted successfully
    And the document "Important Doc" should still exist
    And the document should no longer be associated with a project

  # Authorization Summary

  Scenario: Owner has full access to all projects in workspace
    Given I am logged in as "alice@example.com"
    And a project exists with name "Team Project" owned by "charlie@example.com"
    Then I should be able to view the project
    And I should be able to update the project
    And I should be able to delete the project

  Scenario: Admin has full access to all projects in workspace
    Given I am logged in as "bob@example.com"
    And a project exists with name "Team Project" owned by "charlie@example.com"
    Then I should be able to view the project
    And I should be able to update the project
    And I should be able to delete the project

  Scenario: Member has limited access to projects
    Given I am logged in as "charlie@example.com"
    And a project exists with name "Alice's Project" owned by "alice@example.com"
    And a project exists with name "Charlie's Project" owned by "charlie@example.com"
    Then I should be able to view "Alice's Project"
    But I should not be able to update "Alice's Project"
    And I should not be able to delete "Alice's Project"
    And I should be able to update "Charlie's Project"
    And I should be able to delete "Charlie's Project"

  Scenario: Guest has read-only access to projects
    Given I am logged in as "diana@example.com"
    And a project exists with name "Team Project" in workspace "product-team"
    Then I should be able to view the project
    But I should not be able to create projects
    And I should not be able to update the project
    And I should not be able to delete the project
