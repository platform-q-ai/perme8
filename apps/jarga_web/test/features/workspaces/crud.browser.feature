@browser
Feature: Workspace CRUD Operations
  As a workspace user
  I want to create, edit, and delete workspaces
  So that I can organize my team's work

  # Seed data (from exo_seeds_web.exs) provides:
  #   - Workspace "Product Team" with slug "product-team"
  #   - alice@example.com as owner
  #   - bob@example.com as admin
  #   - charlie@example.com as member
  #   - diana@example.com as guest
  #   - eve@example.com as non-member

  # ---------------------------------------------------------------------------
  # Create
  # ---------------------------------------------------------------------------

  Scenario: Owner creates a new workspace
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspaces and create
    And I navigate to "${baseUrl}/app/workspaces"
    And I wait for network idle
    And I click the "New Workspace" link and wait for navigation
    And I wait for network idle
    And I fill "[name='workspace[name]']" with "Marketing Team"
    And I fill "[name='workspace[description]']" with "Marketing campaigns"
    And I fill "[name='workspace[color]']" with "#FF6B6B"
    And I click the "Create Workspace" button and wait for navigation
    And I wait for network idle
    Then I should see "Workspace created successfully"
    And I should see "Marketing Team"
    And the URL should contain "/app/workspaces"

  # ---------------------------------------------------------------------------
  # Update
  # ---------------------------------------------------------------------------

  Scenario: Admin edits workspace details
    # Log in as admin
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate directly to workspace edit page
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/edit"
    And I wait for network idle
    And I clear "[name='workspace[name]']"
    And I fill "[name='workspace[name]']" with "Product Team Updated"
    And I clear "[name='workspace[description]']"
    And I fill "[name='workspace[description]']" with "Updated description"
    And I fill "[name='workspace[color]']" with "#4A90E2"
    And I click the "Update Workspace" button and wait for navigation
    And I wait for network idle
    Then I should see "Workspace updated successfully"
    And I should see "Product Team Updated"

  Scenario: Member cannot edit workspace
    # Log in as member
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace - kebab menu should not show Edit option
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    # Members don't have kebab menu actions for edit
    Then "button[aria-label='Actions menu']" should not exist

  Scenario: Guest cannot edit workspace
    # Log in as guest
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace - kebab menu should not show Edit option
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    # Guests don't have kebab menu actions for edit
    Then "button[aria-label='Actions menu']" should not exist

  # ---------------------------------------------------------------------------
  # Delete
  # ---------------------------------------------------------------------------

  Scenario: Owner deletes workspace
    # Uses throwaway-workspace seed to avoid destroying data needed by other tests
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to throwaway workspace
    And I navigate to "${baseUrl}/app/workspaces/${throwawayWorkspaceSlug}"
    And I wait for network idle
    And I click "button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I accept the next browser dialog
    And I click the "Delete Workspace" button
    And I wait for network idle
    Then I should see "Workspace deleted successfully"
    And the URL should contain "/workspaces"

  Scenario: Admin cannot delete workspace
    # Log in as admin
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace and open kebab menu
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    And I click "button[aria-label='Actions menu']"
    And I wait for 1 seconds
    # Delete option should not be visible to admin (only owner can delete)
    Then I should not see "Delete Workspace"

  # ---------------------------------------------------------------------------
  # Validation
  # ---------------------------------------------------------------------------

  Scenario: Invalid workspace creation shows errors
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to new workspace form and submit with empty name
    And I navigate to "${baseUrl}/app/workspaces/new"
    And I wait for network idle
    And I clear "[name='workspace[name]']"
    And I fill "[name='workspace[description]']" with "Test"
    And I click the "Create Workspace" button
    And I wait for 2 seconds
    Then I should see "can't be blank"
    And I should not see "Workspace created successfully"
    And the URL should contain "/workspaces/new"
