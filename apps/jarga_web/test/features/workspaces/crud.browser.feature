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
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspaces and create
    And I navigate to "${baseUrl}/workspaces"
    And I wait for the page to load
    And I click the "New Workspace" button
    And I wait for the page to load
    And I fill "[data-testid='workspace-name']" with "Marketing Team"
    And I fill "[data-testid='workspace-description']" with "Marketing campaigns"
    And I fill "[data-testid='workspace-color']" with "#FF6B6B"
    And I click the "Create Workspace" button
    And I wait for network idle
    Then I should see "Workspace created successfully"
    And I should see "Marketing Team"
    And the URL should contain "/workspaces/marketing-team"

  # ---------------------------------------------------------------------------
  # Update
  # ---------------------------------------------------------------------------

  Scenario: Admin edits workspace details
    # Log in as admin
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace and edit
    And I navigate to "${baseUrl}/workspaces/${productTeamSlug}"
    And I wait for the page to load
    And I click the "Edit Workspace" button
    And I wait for the page to load
    And I clear "[data-testid='workspace-name']"
    And I fill "[data-testid='workspace-name']" with "Product Team Updated"
    And I clear "[data-testid='workspace-description']"
    And I fill "[data-testid='workspace-description']" with "Updated description"
    And I fill "[data-testid='workspace-color']" with "#4A90E2"
    And I click the "Save Changes" button
    And I wait for network idle
    Then I should see "Workspace updated successfully"
    And I should see "Product Team Updated"

  Scenario: Member cannot edit workspace
    # Log in as member
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace - Edit button should not be visible
    And I navigate to "${baseUrl}/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should not see "Edit Workspace"
    # Attempt direct navigation to the edit page
    When I navigate to "${baseUrl}/workspaces/${productTeamSlug}/edit"
    And I wait for the page to load
    Then I should see "You are not authorized to perform this action"

  Scenario: Guest cannot edit workspace
    # Log in as guest
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace - Edit button should not be visible
    And I navigate to "${baseUrl}/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should not see "Edit Workspace"
    # Attempt direct navigation to the edit page
    When I navigate to "${baseUrl}/workspaces/${productTeamSlug}/edit"
    And I wait for the page to load
    Then I should see "You are not authorized to perform this action"

  # ---------------------------------------------------------------------------
  # Delete
  # ---------------------------------------------------------------------------

  Scenario: Owner deletes workspace
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace and delete
    And I navigate to "${baseUrl}/workspaces/${productTeamSlug}"
    And I wait for the page to load
    And I click the "Delete Workspace" button
    And I wait for "[data-testid='confirm-delete']" to be visible
    And I click "[data-testid='confirm-delete']"
    And I wait for network idle
    Then I should see "Workspace deleted successfully"
    And the URL should contain "/workspaces"
    And I should not see "Product Team"

  Scenario: Admin cannot delete workspace
    # Log in as admin
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace - Delete button should not be visible
    And I navigate to "${baseUrl}/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should not see "Delete Workspace"

  # ---------------------------------------------------------------------------
  # Validation
  # ---------------------------------------------------------------------------

  Scenario: Invalid workspace creation shows errors
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to new workspace form and submit empty name
    And I navigate to "${baseUrl}/workspaces"
    And I wait for the page to load
    And I click the "New Workspace" button
    And I wait for the page to load
    And I clear "[data-testid='workspace-name']"
    And I fill "[data-testid='workspace-description']" with "Test"
    And I click the "Create Workspace" button
    And I wait for 2 seconds
    Then I should see "can't be blank"
    And I should not see "Workspace created successfully"
    And the URL should contain "/workspaces/new"
