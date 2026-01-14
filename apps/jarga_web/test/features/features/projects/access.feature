Feature: Project Access Control
  As a workspace member
  I want project permissions to be enforced
  So that only authorized users can manage projects

Background:
  Given a workspace exists with name "Product Team" and slug "product-team"
  And a user "alice@example.com" exists as owner of workspace "product-team"
  And a user "bob@example.com" exists as admin of workspace "product-team"
  And a user "charlie@example.com" exists as member of workspace "product-team"
  And a user "diana@example.com" exists as guest of workspace "product-team"
  And a user "eve@example.com" exists but is not a member of workspace "product-team"


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

  Scenario: Projects are scoped to workspace
    Given I am logged in as "alice@example.com"
    And a workspace exists with name "Marketing Team" and slug "marketing-team"
    And user "alice@example.com" is owner of workspace "marketing-team"
    And a project exists with name "Campaign" in workspace "marketing-team"
    When I list projects in workspace "product-team"
    Then I should not see "Campaign"

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
