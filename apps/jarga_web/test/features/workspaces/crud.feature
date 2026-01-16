Feature: Workspace CRUD Operations
  As a workspace user
  I want to create, edit, and delete workspaces
  So that I can organize my team's work

Background:
  Given a workspace exists with name "Product Team" and slug "product-team"
  And a user "alice@example.com" exists as owner of workspace "product-team"
  And a user "bob@example.com" exists as admin of workspace "product-team"
  And a user "charlie@example.com" exists as member of workspace "product-team"
  And a user "diana@example.com" exists as guest of workspace "product-team"
  And a user "eve@example.com" exists but is not a member of workspace "product-team"


  Scenario: Owner creates a new workspace
    Given I am logged in as "alice@example.com"
    When I navigate to the workspaces page
    And I click "New Workspace"
    And I fill in the workspace form with:
      | Field        | Value              |
      | Name         | Marketing Team     |
      | Description  | Marketing campaigns |
      | Color        | #FF6B6B            |
    And I submit the form
    Then I should see "Workspace created successfully"
    And I should see "Marketing Team" in the workspace list
    And the workspace should have slug "marketing-team"

  Scenario: Admin edits workspace details
    Given I am logged in as "bob@example.com"
    When I navigate to workspace "product-team"
    And I click "Edit Workspace"
    And I fill in the workspace form with:
      | Field        | Value                    |
      | Name         | Product Team Updated     |
      | Description  | Updated description      |
      | Color        | #4A90E2                 |
    And I submit the form
    Then I should see "Workspace updated successfully"
    And I should see "Product Team Updated"

  Scenario: Member cannot edit workspace
    Given I am logged in as "charlie@example.com"
    When I navigate to workspace "product-team"
    Then I should not see "Edit Workspace"
    And I attempt to edit workspace "product-team"
    Then I should receive a forbidden error

  Scenario: Guest cannot edit workspace
    Given I am logged in as "diana@example.com"
    When I navigate to workspace "product-team"
    Then I should not see "Edit Workspace"
    And I attempt to edit workspace "product-team"
    Then I should receive a forbidden error

  Scenario: Owner deletes workspace
    Given I am logged in as "alice@example.com"
    And I navigate to workspace "product-team"
    When I click "Delete Workspace"
    And I confirm the workspace deletion
    Then I should see "Workspace deleted successfully"
    And I should be redirected to the workspaces page
    And I should not see "Product Team" in the workspace list

  Scenario: Admin cannot delete workspace
    Given I am logged in as "bob@example.com"
    When I navigate to workspace "product-team"
    Then I should not see "Delete Workspace"
    And I attempt to delete workspace "product-team"
    Then I should receive a forbidden error

  Scenario: Invalid workspace creation shows errors
    Given I am logged in as "alice@example.com"
    When I navigate to the workspaces page
    And I click "New Workspace"
    And I fill in the workspace form with:
      | Field        | Value |
      | Name         |       |
      | Description  | Test  |
    And I submit the form
    Then I should see validation errors
    And I should not see "Workspace created successfully"
    And I should remain on the new workspace page
