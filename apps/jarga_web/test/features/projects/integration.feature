Feature: Project Integration
  As a workspace member
  I want projects to integrate with workspaces and documents
  So that I have a cohesive organization experience

Background:
  Given a workspace exists with name "Product Team" and slug "product-team"
  And a user "alice@example.com" exists as owner of workspace "product-team"
  And a user "bob@example.com" exists as admin of workspace "product-team"
  And a user "charlie@example.com" exists as member of workspace "product-team"
  And a user "diana@example.com" exists as guest of workspace "product-team"
  And a user "eve@example.com" exists but is not a member of workspace "product-team"


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

  # Navigation

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
