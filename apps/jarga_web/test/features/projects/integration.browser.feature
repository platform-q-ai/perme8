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
  #   - Projects: "Q1 Launch" (slug: q1-launch), "Mobile App" (slug: mobile-app)
  #   - Document: "Launch Plan" in project "Q1 Launch"

  # ---------------------------------------------------------------------------
  # Real-time Notifications
  # ---------------------------------------------------------------------------

  # Note: Multi-user real-time PubSub scenarios (e.g., "user B sees update pushed
  # by user A") require two concurrent browser sessions and are not feasible with
  # a single-browser adapter. The scenarios below verify the acting user's own
  # view after the action, which exercises the same LiveView PubSub handlers.

  Scenario: Project creation reflects in workspace view
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    And I click the "New Project" button
    And I wait for "#project-form" to be visible
    And I fill "[name='project[name]']" with "Real-time Test Project"
    And I click the "Create Project" button
    And I wait for network idle
    Then I should see "Project created successfully"
    And I should see "Real-time Test Project"

  Scenario: Project update reflects after save
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app/edit"
    And I wait for network idle
    And I wait for "#project-form" to be visible
    And I clear "[name='project[name]']"
    And I fill "[name='project[name]']" with "Mobile Application"
    And I click the "Update Project" button
    And I wait for network idle
    Then I should see "Project updated successfully"
    And I should see "Mobile Application"

  @wip
  Scenario: Project deletion reflects in workspace view
    # Delete uses data-confirm native dialog - cannot be automated
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/q1-launch"
    And I wait for network idle
    And I click "button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I click the "Delete Project" button
    And I wait for network idle
    Then I should see "Project deleted successfully"
    And the URL should contain "/workspaces/${productTeamSlug}"
    And I should not see "Q1 Launch"

  # ---------------------------------------------------------------------------
  # Navigation
  # ---------------------------------------------------------------------------

  Scenario: Breadcrumb navigation in project view
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app"
    And I wait for network idle
    Then I should see "Home"
    And I should see "Workspaces"
    And I should see "Product Team"
    And I should see "Mobile App"

  Scenario: Navigate from project show to edit via kebab menu
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app"
    And I wait for network idle
    And I click "button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I click the "Edit Project" link and wait for navigation
    And I wait for network idle
    Then "#project-form" should be visible
    And the URL should contain "/projects/mobile-app/edit"

  # ---------------------------------------------------------------------------
  # Document Association
  # ---------------------------------------------------------------------------

  Scenario: Project shows associated documents
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/q1-launch"
    And I wait for network idle
    Then I should see "Launch Plan"
    And I should see "Documents"

  Scenario: Project show page has New Document button
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/q1-launch"
    And I wait for network idle
    Then I should see "New Document"

  Scenario: Project show page displays project details card
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/q1-launch"
    And I wait for network idle
    Then I should see "Q1 Launch"
