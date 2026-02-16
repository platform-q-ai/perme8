@browser
Feature: Workspace Member Management
  As a workspace admin
  I want to invite and manage workspace members
  So that I can control who has access to the workspace

  # Seed data (from exo_seeds_web.exs) provides:
  #   - Workspace "Product Team" with slug "product-team"
  #   - alice@example.com as owner
  #   - bob@example.com as admin
  #   - charlie@example.com as member
  #   - diana@example.com as guest
  #   - eve@example.com as non-member

  # ---------------------------------------------------------------------------
  # Invite Members
  # ---------------------------------------------------------------------------

  Scenario: Admin invites new member
    # Log in as admin
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace members
    And I navigate to "${baseUrl}/workspaces/${productTeamSlug}"
    And I wait for the page to load
    And I click the "Manage Members" link
    And I wait for the page to load
    # Invite eve
    And I fill "[data-testid='invite-email']" with "${nonMemberEmail}"
    And I select "member" from "[data-testid='invite-role']"
    And I click the "Invite" button
    And I wait for network idle
    Then I should see "${nonMemberEmail}"
    And I should see "Pending"

  Scenario: Member cannot invite other members
    # Log in as member
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace - Manage Members should not be visible
    And I navigate to "${baseUrl}/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should not see "Manage Members"
    # Attempt direct navigation to members page
    When I navigate to "${baseUrl}/workspaces/${productTeamSlug}/members"
    And I wait for the page to load
    Then I should see "You are not authorized to perform this action"

  # ---------------------------------------------------------------------------
  # Change Member Role
  # ---------------------------------------------------------------------------

  Scenario: Admin changes member role
    # Log in as admin
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace members
    And I navigate to "${baseUrl}/workspaces/${productTeamSlug}"
    And I wait for the page to load
    And I click the "Manage Members" link
    And I wait for the page to load
    # Change charlie's role to admin
    And I select "admin" from "[data-testid='role-select-${memberEmail}']"
    And I wait for network idle
    Then I should see "Member role updated successfully"

  Scenario: Admin cannot change owner's role
    # Log in as admin
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace members
    And I navigate to "${baseUrl}/workspaces/${productTeamSlug}"
    And I wait for the page to load
    And I click the "Manage Members" link
    And I wait for the page to load
    # Owner's role selector should not exist or be disabled
    Then "[data-testid='role-select-${ownerEmail}']" should not exist
    And I should see "Owner"

  # ---------------------------------------------------------------------------
  # Remove Members
  # ---------------------------------------------------------------------------

  Scenario: Admin removes member
    # Log in as admin
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace members
    And I navigate to "${baseUrl}/workspaces/${productTeamSlug}"
    And I wait for the page to load
    And I click the "Manage Members" link
    And I wait for the page to load
    # Remove charlie
    And I click "[data-testid='remove-member-${memberEmail}']"
    And I wait for network idle
    Then I should see "Member removed successfully"
    And I should not see "${memberEmail}"

  Scenario: Admin cannot remove owner
    # Log in as admin
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace members
    And I navigate to "${baseUrl}/workspaces/${productTeamSlug}"
    And I wait for the page to load
    And I click the "Manage Members" link
    And I wait for the page to load
    # Remove button for owner should not exist
    Then "[data-testid='remove-member-${ownerEmail}']" should not exist

  # ---------------------------------------------------------------------------
  # Access Control
  # ---------------------------------------------------------------------------

  Scenario: Non-member cannot access workspace
    # Log in as non-member
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${nonMemberEmail}"
    And I fill "#login_form_password_password" with "${nonMemberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Attempt to navigate to workspace
    And I navigate to "${baseUrl}/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then the URL should contain "/workspaces"
    And I should see "You are not authorized to perform this action"
