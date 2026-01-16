Feature: Workspace Navigation
  As a workspace user
  I want to navigate between workspaces and view workspace content
  So that I can easily access my team's work

Background:
  Given a workspace exists with name "Product Team" and slug "product-team"
  And a user "alice@example.com" exists as owner of workspace "product-team"
  And a user "bob@example.com" exists as admin of workspace "product-team"
  And a user "charlie@example.com" exists as member of workspace "product-team"
  And a user "diana@example.com" exists as guest of workspace "product-team"
  And a user "eve@example.com" exists but is not a member of workspace "product-team"


  Scenario: Member views workspace details
    Given I am logged in as "charlie@example.com"
    When I navigate to workspace "product-team"
    Then I should see "Product Team"
    And I should see the workspace description
    And I should see the projects section
    And I should see the documents section
    And I should see the agents section

  Scenario: Guest can view workspace but limited actions
    Given I am logged in as "diana@example.com"
    When I navigate to workspace "product-team"
    Then I should see "Product Team"
    And I should not see "New Project" button
    And I should not see "New Document" button
    And I should not see "Manage Members"

  Scenario: Member can create projects and documents
    Given I am logged in as "charlie@example.com"
    When I navigate to workspace "product-team"
    Then I should see "New Project" button
    And I should see "New Document" button
    And I should be able to create a project
    And I should be able to create a document

  Scenario: Workspace list shows all user workspaces
    Given a workspace exists with name "Engineering" and slug "engineering"
    And a user "alice@example.com" exists as owner of workspace "engineering"
    And I am logged in as "alice@example.com"
    When I navigate to the workspaces page
    Then I should see "Product Team" in the workspace list
    And I should see "Engineering" in the workspace list
    And each workspace should show its description
    And each workspace should be clickable

  Scenario: Empty workspace list shows helpful message
    Given a user "newuser@example.com" exists but is not a member of any workspace
    And I am logged in as "newuser@example.com"
    When I navigate to the workspaces page
    Then I should see "No workspaces yet"
    And I should see "Create your first workspace to get started"
    And I should see a "Create Workspace" button

  Scenario: Workspace with color displays correctly
    Given I am logged in as "alice@example.com"
    And a workspace exists with name "Design Team" and slug "design-team" and color "#FF6B6B"
    And a user "alice@example.com" exists as owner of workspace "design-team"
    When I navigate to the workspaces page
    Then I should see "Design Team" in the workspace list
    And I should see a color bar with color "#FF6B6B" for the workspace
