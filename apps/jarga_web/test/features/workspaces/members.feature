Feature: Workspace Member Management
  As a workspace admin
  I want to invite and manage workspace members
  So that I can control who has access to the workspace

Background:
  Given a workspace exists with name "Product Team" and slug "product-team"
  And a user "alice@example.com" exists as owner of workspace "product-team"
  And a user "bob@example.com" exists as admin of workspace "product-team"
  And a user "charlie@example.com" exists as member of workspace "product-team"
  And a user "diana@example.com" exists as guest of workspace "product-team"
  And a user "eve@example.com" exists but is not a member of workspace "product-team"


  Scenario: Admin invites new member (non-Jarga user)
    Given I am logged in as "bob@example.com"
    When I navigate to workspace "product-team"
    And I click "Manage Members"
    And I invite "eve@example.com" as "member"
    Then I should see "eve@example.com" in the members list with status "Pending"
    And an invitation email should be queued

  Scenario: Admin adds existing Jarga user as member
    Given a user "frank@example.com" exists but is not a member of workspace "product-team"
    And I am logged in as "bob@example.com"
    When I navigate to workspace "product-team"
    And I click "Manage Members"
    And I invite "frank@example.com" as "admin"
    Then I should see "frank@example.com" in the members list with status "Active"
    And a notification email should be queued

  Scenario: Member cannot invite other members
    Given I am logged in as "charlie@example.com"
    When I navigate to workspace "product-team"
    Then I should not see "Manage Members"
    And I attempt to invite "new@example.com" as "member" to workspace "product-team"
    Then I should receive a forbidden error

  Scenario: Admin changes member role
    Given I am logged in as "bob@example.com"
    When I navigate to workspace "product-team"
    And I click "Manage Members"
    And I change "charlie@example.com"'s role to "admin"
    Then I should see "Member role updated successfully"
    And "charlie@example.com" should have role "admin" in the members list

  Scenario: Admin cannot change owner's role
    Given I am logged in as "bob@example.com"
    When I navigate to workspace "product-team"
    And I click "Manage Members"
    And I attempt to change "alice@example.com"'s role
    Then I should not see a role selector for "alice@example.com"
    And the owner role should be read-only

  Scenario: Admin removes member
    Given I am logged in as "bob@example.com"
    When I navigate to workspace "product-team"
    And I click "Manage Members"
    And I remove "charlie@example.com" from the workspace
    Then I should see "Member removed successfully"
    And I should not see "charlie@example.com" in the members list

  Scenario: Admin cannot remove owner
    Given I am logged in as "bob@example.com"
    When I navigate to workspace "product-team"
    And I click "Manage Members"
    And I attempt to remove "alice@example.com" from the workspace
    Then I should not see a remove button for "alice@example.com"
    And I should receive a "cannot remove owner" error

  Scenario: Non-member cannot access workspace
    Given a user "outsider@example.com" exists but is not a member of workspace "product-team"
    And I am logged in as "outsider@example.com"
    When I attempt to navigate to workspace "product-team"
    Then I should receive an unauthorized error
    And I should be redirected to the workspaces page
