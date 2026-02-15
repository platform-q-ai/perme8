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
  #   - Projects: "Q1 Launch", "Mobile App" (owned by alice)

  # ---------------------------------------------------------------------------
  # Project Creation
  # ---------------------------------------------------------------------------

  Scenario: Owner creates a project in workspace
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Navigate to workspace
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    # Open new project modal
    And I click the "New Project" button
    And I wait for ".modal-open" to be visible
    # Fill in project details
    And I fill "#project_name" with "Browser Test Project"
    And I click the "Create Project" button
    And I wait for network idle
    Then I should see "Project created successfully"
    And I should see "Browser Test Project"

  Scenario: Admin creates a project in workspace
    # Log in as admin
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Navigate to workspace
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    # Open new project modal and create
    And I click the "New Project" button
    And I wait for ".modal-open" to be visible
    And I fill "#project_name" with "Admin Project"
    And I click the "Create Project" button
    And I wait for network idle
    Then I should see "Project created successfully"
    And I should see "Admin Project"

  Scenario: Member creates a project in workspace
    # Log in as member
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Navigate to workspace
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    # Open new project modal and create
    And I click the "New Project" button
    And I wait for ".modal-open" to be visible
    And I fill "#project_name" with "Member Project"
    And I click the "Create Project" button
    And I wait for network idle
    Then I should see "Project created successfully"
    And I should see "Member Project"

  Scenario: Guest cannot create projects
    # Log in as guest
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Navigate to workspace - New Project button should not be visible
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should not see "New Project"

  Scenario: Non-member cannot create projects
    # Log in as non-member
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${nonMemberEmail}"
    And I fill "#login_form_password_password" with "${nonMemberPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Attempt to navigate to workspace - should be redirected
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should see "Workspace not found"
    And the URL should contain "/workspaces"

  Scenario: Create project with full details
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Navigate to workspace
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    # Open new project modal and fill all fields
    And I click the "New Project" button
    And I wait for ".modal-open" to be visible
    And I fill "#project_name" with "Web App"
    And I fill "#project_description" with "Our main web application"
    And I fill "#project_color" with "#3B82F6"
    And I click the "Create Project" button
    And I wait for network idle
    Then I should see "Project created successfully"
    And I should see "Web App"

  Scenario: Create project with empty name shows validation error
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Navigate to workspace
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    # Open new project modal and submit with empty name
    And I click the "New Project" button
    And I wait for ".modal-open" to be visible
    And I clear "#project_name"
    And I click the "Create Project" button
    And I wait for 2 seconds
    Then I should see "can't be blank"
    And I should not see "Project created successfully"

  # ---------------------------------------------------------------------------
  # Project Updates
  # ---------------------------------------------------------------------------

  Scenario: Owner updates their own project name
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Navigate to a seeded project and edit
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/q1-launch/edit"
    And I wait for the page to load
    And I clear "#project_name"
    And I fill "#project_name" with "Q1 Launch Updated"
    And I click the "Update Project" button
    And I wait for network idle
    Then I should see "Project updated successfully"
    And I should see "Q1 Launch Updated"

  Scenario: Owner updates project description
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Navigate to project edit page
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app/edit"
    And I wait for the page to load
    And I clear "#project_description"
    And I fill "#project_description" with "iOS and Android applications"
    And I click the "Update Project" button
    And I wait for network idle
    Then I should see "Project updated successfully"
    And I should see "iOS and Android applications"

  Scenario: Owner updates project color
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Navigate to project edit page
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app/edit"
    And I wait for the page to load
    And I clear "#project_color"
    And I fill "#project_color" with "#10B981"
    And I click the "Update Project" button
    And I wait for network idle
    Then I should see "Project updated successfully"

  Scenario: Guest cannot update any projects
    # Log in as guest
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Navigate to a seeded project - Edit button should not be accessible
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app"
    And I wait for the page to load
    Then I should not see "Edit Project"
    # Attempt direct navigation to the edit page
    When I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app/edit"
    And I wait for the page to load
    Then the URL should contain "/workspaces"

  Scenario: Update project with empty name shows validation error
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Navigate to project edit page
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app/edit"
    And I wait for the page to load
    And I clear "#project_name"
    And I click the "Update Project" button
    And I wait for 2 seconds
    Then I should see "can't be blank"
    And I should not see "Project updated successfully"

  # ---------------------------------------------------------------------------
  # Project Deletion
  # ---------------------------------------------------------------------------

  Scenario: Owner deletes their own project
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Navigate to a seeded project
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/q1-launch"
    And I wait for the page to load
    # Click delete from kebab menu
    And I click the "Delete Project" button
    And I wait for network idle
    Then I should see "Project deleted successfully"
    And the URL should contain "/workspaces/${productTeamSlug}"

  Scenario: Guest cannot delete any projects
    # Log in as guest
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Navigate to a seeded project - Delete button should not be visible
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app"
    And I wait for the page to load
    Then I should not see "Delete Project"

  Scenario: Non-member cannot delete projects
    # Log in as non-member
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${nonMemberEmail}"
    And I fill "#login_form_password_password" with "${nonMemberPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Attempt to navigate to workspace - should be redirected
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should see "Workspace not found"
    And the URL should contain "/workspaces"
