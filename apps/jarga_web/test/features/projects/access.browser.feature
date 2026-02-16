@browser
Feature: Project Access Control
  As a workspace member
  I want project permissions to be enforced
  So that only authorized users can manage projects

  # Seed data (from exo_seeds_web.exs) provides:
  #   - Workspace "Product Team" with slug "product-team"
  #   - alice@example.com as owner (password: hello world!)
  #   - bob@example.com as admin
  #   - charlie@example.com as member
  #   - diana@example.com as guest
  #   - eve@example.com as non-member
  #   - Projects: "Q1 Launch" (slug: q1-launch), "Mobile App" (slug: mobile-app) owned by alice

  # ---------------------------------------------------------------------------
  # Project Listing
  # ---------------------------------------------------------------------------

  Scenario: List all projects in workspace
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace and verify seeded projects are listed
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should see "Q1 Launch"
    And I should see "Mobile App"

  Scenario: Guest can view projects in workspace
    # Log in as guest
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace - guest should see projects
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should see "Q1 Launch"
    And I should see "Mobile App"

  Scenario: Non-member cannot list projects
    # Log in as non-member
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${nonMemberEmail}"
    And I fill "#login_form_password_password" with "${nonMemberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Attempt to navigate to workspace - should be redirected
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should see "Workspace not found"
    And I should not see "Q1 Launch"
    And I should not see "Mobile App"

  Scenario: Projects are scoped to workspace
    # Log in as owner (alice owns both workspaces)
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to engineering workspace - should NOT see product-team projects
    And I navigate to "${baseUrl}/app/workspaces/${engineeringSlug}"
    And I wait for the page to load
    Then I should not see "Q1 Launch"
    And I should not see "Mobile App"

  # ---------------------------------------------------------------------------
  # Authorization Summary
  # ---------------------------------------------------------------------------

  Scenario: Owner has full access to all projects in workspace
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to a seeded project
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app"
    And I wait for the page to load
    # Owner should see edit and delete options
    Then I should see "Edit Project"
    And I should see "Delete Project"

  Scenario: Admin has full access to all projects in workspace
    # Log in as admin
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to a seeded project
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app"
    And I wait for the page to load
    # Admin should see edit and delete options
    Then I should see "Edit Project"
    And I should see "Delete Project"

  Scenario: Member can view projects but cannot edit others' projects
    # Log in as member
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace - member can see projects
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should see "Q1 Launch"
    And I should see "Mobile App"
    # Navigate to alice's project - member should not see edit/delete
    When I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app"
    And I wait for the page to load
    Then I should not see "Edit Project"
    And I should not see "Delete Project"
    # Attempt direct navigation to edit page
    When I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app/edit"
    And I wait for the page to load
    Then the URL should contain "/workspaces"

  Scenario: Guest has read-only access to projects
    # Log in as guest
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace - guest can see projects
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should see "Q1 Launch"
    And I should see "Mobile App"
    # Guest should not see New Project button
    And I should not see "New Project"
    # Navigate to a project - guest should not see edit/delete
    When I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app"
    And I wait for the page to load
    Then I should not see "Edit Project"
    And I should not see "Delete Project"
