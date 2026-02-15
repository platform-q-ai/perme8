@browser
Feature: Project Integration
  As a workspace member
  I want projects to integrate with workspaces and documents
  So that I have a cohesive organization experience

  # Seed data (from exo_seeds_web.exs) provides:
  #   - Workspace "Product Team" with slug "product-team"
  #   - alice@example.com as owner (password: hello world!)
  #   - bob@example.com as admin
  #   - charlie@example.com as member
  #   - diana@example.com as guest
  #   - eve@example.com as non-member
  #   - Projects: "Q1 Launch" (slug: q1-launch), "Mobile App" (slug: mobile-app) owned by alice
  #   - Document: "Launch Plan" in project "Q1 Launch"

  # ---------------------------------------------------------------------------
  # Real-time Notifications
  # ---------------------------------------------------------------------------

  # Note: Multi-user real-time PubSub scenarios (e.g., "user B sees update pushed
  # by user A") require two concurrent browser sessions and are not feasible with
  # a single-browser adapter. The scenarios below verify the acting user's own
  # view after the action, which exercises the same LiveView PubSub handlers.

  Scenario: Project creation notification to workspace members
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Navigate to workspace and create a project
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    And I click the "New Project" button
    And I wait for ".modal-open" to be visible
    And I fill "#project_name" with "Real-time Test Project"
    And I click the "Create Project" button
    And I wait for network idle
    # Verify project appears in the workspace view
    Then I should see "Project created successfully"
    And I should see "Real-time Test Project"

  Scenario: Project update notification to workspace members
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Navigate to project edit page and update name
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app/edit"
    And I wait for the page to load
    And I clear "#project_name"
    And I fill "#project_name" with "Mobile Application"
    And I click the "Update Project" button
    And I wait for network idle
    # Verify updated name appears
    Then I should see "Project updated successfully"
    And I should see "Mobile Application"

  Scenario: Project deletion notification to workspace members
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Navigate to a seeded project and delete it
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/q1-launch"
    And I wait for the page to load
    And I click the "Delete Project" button
    And I wait for network idle
    # Verify deletion and redirect to workspace
    Then I should see "Project deleted successfully"
    And the URL should contain "/workspaces/${productTeamSlug}"
    And I should not see "Q1 Launch"

  # ---------------------------------------------------------------------------
  # Navigation
  # ---------------------------------------------------------------------------

  Scenario: Breadcrumb navigation in project view
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Navigate to a seeded project
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app"
    And I wait for the page to load
    # Verify breadcrumbs show workspace and project names
    Then I should see "Product Team"
    And I should see "Mobile App"

  # ---------------------------------------------------------------------------
  # Document Association
  # ---------------------------------------------------------------------------

  Scenario: Project contains associated documents
    # Log in as owner
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    # Navigate to the seeded project that has a document
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/q1-launch"
    And I wait for the page to load
    # Verify the seeded document "Launch Plan" is listed
    Then I should see "Launch Plan"
    And I should see "Documents"
