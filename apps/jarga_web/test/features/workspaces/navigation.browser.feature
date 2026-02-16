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
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace
    And I navigate to "${baseUrl}/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should see "Product Team"
    And "[data-testid='workspace-description']" should be visible
    And "[data-testid='projects-section']" should be visible
    And "[data-testid='documents-section']" should be visible
    And "[data-testid='agents-section']" should be visible

  Scenario: Guest can view workspace but limited actions
    # Log in as guest
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace
    And I navigate to "${baseUrl}/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should see "Product Team"
    And I should not see "New Project"
    And I should not see "New Document"
    And I should not see "Manage Members"

  Scenario: Member can create projects and documents
    # Log in as member
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace
    And I navigate to "${baseUrl}/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should see "New Project"
    And I should see "New Document"
    And "[data-testid='new-project-btn']" should be enabled
    And "[data-testid='new-document-btn']" should be enabled

  # ---------------------------------------------------------------------------
  # Workspace List
  # ---------------------------------------------------------------------------

  Scenario: Workspace list shows all user workspaces
    # Log in as owner (alice has both Product Team and Engineering)
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspaces list
    And I navigate to "${baseUrl}/workspaces"
    And I wait for the page to load
    Then I should see "Product Team"
    And I should see "Engineering"
    And "[data-testid='workspace-card-${productTeamSlug}']" should be visible
    And "[data-testid='workspace-card-${engineeringSlug}']" should be visible

  Scenario: Empty workspace list shows helpful message
    # Log in as non-member (eve is not a member of any workspace)
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${nonMemberEmail}"
    And I fill "#login_form_password_password" with "${nonMemberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspaces list
    And I navigate to "${baseUrl}/workspaces"
    And I wait for the page to load
    Then I should see "No workspaces yet"
    And I should see "Create your first workspace to get started"
    And I should see "Create Workspace"

  Scenario: Workspace with color displays correctly
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspaces list
    And I navigate to "${baseUrl}/workspaces"
    And I wait for the page to load
    Then I should see "Product Team"
    And "[data-testid='workspace-color-bar']" should be visible
