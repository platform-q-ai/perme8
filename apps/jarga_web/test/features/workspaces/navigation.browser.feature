@browser
Feature: Workspace Navigation
  As a workspace user
  I want to navigate between workspaces and view workspace content
  So that I can easily access my team's work

  # Seed data (from exo_seeds_web.exs) provides:
  #   - Workspace "Product Team" with slug "product-team"
  #   - Workspace "Engineering" with slug "engineering" (alice is owner)
  #   - alice@example.com as owner
  #   - bob@example.com as admin
  #   - charlie@example.com as member
  #   - diana@example.com as guest
  #   - eve@example.com as non-member

  # ---------------------------------------------------------------------------
  # Workspace Details View
  # ---------------------------------------------------------------------------

  Scenario: Member views workspace details
    # Log in as member
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for the page to load
    # Navigate to workspace
    When I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    And I wait for network idle
    Then the URL should contain "/app/workspaces/product-team"
    And I should see "Product Team"
    And I should see "Projects"
    And I should see "Documents"
    And I should see "Agents"

  Scenario: Guest can view workspace but limited actions
    # Log in as guest
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should see "Product Team"
    And I should not see "New Project"
    And I should not see "New Document"
    And I should not see "Manage Members"

  Scenario: Member can see project and document actions
    # Log in as member
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should see "New Project"
    And I should see "New Document"

  # ---------------------------------------------------------------------------
  # Workspace List
  # ---------------------------------------------------------------------------

  Scenario: Workspace list shows all user workspaces
    # Log in as owner (alice has both Product Team and Engineering)
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspaces list
    And I navigate to "${baseUrl}/app/workspaces"
    And I wait for the page to load
    Then I should see "Product Team"
    And I should see "Engineering"
    And "a[href='/app/workspaces/${productTeamSlug}']" should exist
    And "a[href='/app/workspaces/${engineeringSlug}']" should exist

  Scenario: Clicking workspace card navigates to workspace
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspaces list and click a workspace
    And I navigate to "${baseUrl}/app/workspaces"
    And I wait for the page to load
    And I click the "Product Team" link
    And I wait for network idle
    Then the URL should contain "/app/workspaces/${productTeamSlug}"
    And I should see "Product Team"
    And I should see "Projects"

  Scenario: Empty workspace list shows helpful message
    # Log in as non-member (eve is not a member of any workspace)
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${nonMemberEmail}"
    And I fill "#login_form_password_password" with "${nonMemberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspaces list
    And I navigate to "${baseUrl}/app/workspaces"
    And I wait for the page to load
    Then I should see "No workspaces yet"
    And I should see "Create your first workspace to get started"

  Scenario: New Workspace link is available on workspace index
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspaces list
    And I navigate to "${baseUrl}/app/workspaces"
    And I wait for the page to load
    Then "a[href='/app/workspaces/new']" should exist
    And I should see "New Workspace"
