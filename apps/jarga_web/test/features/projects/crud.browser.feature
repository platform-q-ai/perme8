@browser
Feature: Project CRUD Operations
  As a workspace member
  I want to create, update, and delete projects
  So that I can organize documents within my workspace

  # Seed data (from exo_seeds_web.exs) provides:
  #   - Workspace "Product Team" with slug "product-team"
  #   - alice@example.com as owner (password: hello world!)
  #   - bob@example.com as admin
  #   - charlie@example.com as member
  #   - diana@example.com as guest
  #   - eve@example.com as non-member
  #   - Projects: "Q1 Launch" (slug: q1-launch), "Mobile App" (slug: mobile-app)
  #   - All seeded projects are owned by alice

  # ---------------------------------------------------------------------------
  # Project Creation (via modal on workspace show page)
  # ---------------------------------------------------------------------------

  Scenario: Owner creates a project in workspace
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    # Open new project modal
    And I click the "New Project" button
    And I wait for "#project-form" to be visible
    # Fill in project details
    And I fill "[name='project[name]']" with "Browser Test Project"
    And I click the "Create Project" button
    And I wait for network idle
    Then I should see "Project created successfully"
    And I should see "Browser Test Project"

  Scenario: Admin creates a project in workspace
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    And I click the "New Project" button
    And I wait for "#project-form" to be visible
    And I fill "[name='project[name]']" with "Admin Project"
    And I click the "Create Project" button
    And I wait for network idle
    Then I should see "Project created successfully"
    And I should see "Admin Project"

  Scenario: Member creates a project in workspace
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    And I click the "New Project" button
    And I wait for "#project-form" to be visible
    And I fill "[name='project[name]']" with "Member Project"
    And I click the "Create Project" button
    And I wait for network idle
    Then I should see "Project created successfully"
    And I should see "Member Project"

  Scenario: Guest cannot create projects
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    Then I should not see "New Project"

  Scenario: Non-member cannot access workspace to create projects
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${nonMemberEmail}"
    And I fill "#login_form_password_password" with "${nonMemberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    Then I should not see "Q1 Launch"
    And I should not see "Mobile App"

  Scenario: Create project with full details
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    And I click the "New Project" button
    And I wait for "#project-form" to be visible
    And I fill "[name='project[name]']" with "Web App"
    And I fill "[name='project[description]']" with "Our main web application"
    And I fill "[name='project[color]']" with "#3B82F6"
    And I click the "Create Project" button
    And I wait for network idle
    Then I should see "Project created successfully"
    And I should see "Web App"

  Scenario: Create project with empty name shows validation error
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    And I click the "New Project" button
    And I wait for "#project-form" to be visible
    And I clear "[name='project[name]']"
    And I click the "Create Project" button
    And I wait for 2 seconds
    Then I should see "can't be blank"
    And I should not see "Project created successfully"

  Scenario: Cancel project creation modal
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    And I click the "New Project" button
    And I wait for "#project-form" to be visible
    And I fill "[name='project[name]']" with "Should Not Be Created"
    And I click the "Cancel" button
    And I wait for "#project-form" to be hidden
    Then I should not see "Should Not Be Created"

  # ---------------------------------------------------------------------------
  # Project Updates (on /app/workspaces/:ws/projects/:proj/edit)
  # ---------------------------------------------------------------------------

  Scenario: Owner updates project name
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/q1-launch/edit"
    And I wait for network idle
    And I wait for "#project-form" to be visible
    And I clear "[name='project[name]']"
    And I fill "[name='project[name]']" with "Q1 Launch Updated"
    And I click the "Update Project" button
    And I wait for network idle
    Then I should see "Project updated successfully"
    And I should see "Q1 Launch Updated"

  Scenario: Owner updates project description
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app/edit"
    And I wait for network idle
    And I wait for "#project-form" to be visible
    And I clear "[name='project[description]']"
    And I fill "[name='project[description]']" with "iOS and Android applications"
    And I click the "Update Project" button
    And I wait for network idle
    Then I should see "Project updated successfully"
    And I should see "iOS and Android applications"

  Scenario: Owner updates project color
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app/edit"
    And I wait for network idle
    And I wait for "#project-form" to be visible
    And I clear "[name='project[color]']"
    And I fill "[name='project[color]']" with "#10B981"
    And I click the "Update Project" button
    And I wait for network idle
    Then I should see "Project updated successfully"

  Scenario: Guest cannot update projects
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to a seeded project - kebab menu should not be visible for guest
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app"
    And I wait for network idle
    Then "button[aria-label='Actions menu']" should not exist
    # Attempt direct navigation to the edit page - should be denied
    When I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app/edit"
    And I wait for network idle
    Then I should see "You are not authorized to edit this project"
    And the URL should contain "/workspaces"

  Scenario: Update project with empty name shows validation error
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app/edit"
    And I wait for network idle
    And I wait for "#project-form" to be visible
    And I clear "[name='project[name]']"
    And I click the "Update Project" button
    And I wait for 2 seconds
    Then I should see "can't be blank"
    And I should not see "Project updated successfully"

  # ---------------------------------------------------------------------------
  # Project Deletion
  # Delete uses phx-click with data-confirm (native browser dialog).
  # Tagged @wip because the browser adapter cannot interact with native dialogs.
  # ---------------------------------------------------------------------------

  @wip
  Scenario: Owner deletes their own project
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/q1-launch"
    And I wait for network idle
    # Delete uses data-confirm native dialog - cannot be automated
    And I click "button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I click the "Delete Project" button
    And I wait for network idle
    Then I should see "Project deleted successfully"
    And the URL should contain "/workspaces/${productTeamSlug}"

  Scenario: Guest cannot delete any projects
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app"
    And I wait for network idle
    # Guest should not see the kebab menu at all
    Then "button[aria-label='Actions menu']" should not exist

  Scenario: Non-member cannot access workspace projects
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${nonMemberEmail}"
    And I fill "#login_form_password_password" with "${nonMemberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    Then I should not see "Q1 Launch"
    And I should not see "Mobile App"
