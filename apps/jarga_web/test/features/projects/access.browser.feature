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
  #   - Projects: "Q1 Launch" (slug: q1-launch), "Mobile App" (slug: mobile-app)
  #   - All seeded projects are owned by alice

  # ---------------------------------------------------------------------------
  # Project Listing
  # ---------------------------------------------------------------------------

  Scenario: Owner can list all projects in workspace
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should see "Q1 Launch"
    And I should see "Mobile App"

  Scenario: Guest can view projects in workspace
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should see "Q1 Launch"
    And I should see "Mobile App"

  Scenario: Non-member cannot list projects
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${nonMemberEmail}"
    And I fill "#login_form_password_password" with "${nonMemberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should not see "Q1 Launch"
    And I should not see "Mobile App"

  Scenario: Projects are scoped to workspace
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to engineering workspace - should NOT see product-team projects
    And I navigate to "${baseUrl}/app/workspaces/${engineeringSlug}"
    And I wait for the page to load
    Then I should not see "Q1 Launch"
    And I should not see "Mobile App"

  # ---------------------------------------------------------------------------
  # Role-based Access on Project Show Page
  # ---------------------------------------------------------------------------

  Scenario: Owner sees edit and delete options on project show
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app"
    And I wait for the page to load
    # Owner should see kebab menu with edit and delete options
    And I click "button[aria-label='Actions menu']"
    And I wait for 1 seconds
    Then I should see "Edit Project"
    And I should see "Delete Project"

  Scenario: Admin sees edit and delete options on project show
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app"
    And I wait for the page to load
    # Admin should see kebab menu with edit and delete options
    And I click "button[aria-label='Actions menu']"
    And I wait for 1 seconds
    Then I should see "Edit Project"
    And I should see "Delete Project"

  Scenario: Member cannot edit or delete others' projects
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Member can see projects on workspace page
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should see "Q1 Launch"
    And I should see "Mobile App"
    # Navigate to project show - member should not see kebab menu for others' projects
    When I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app"
    And I wait for the page to load
    Then "button[aria-label='Actions menu']" should not exist

  Scenario: Guest has read-only access to projects
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Guest can see projects on workspace page
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then I should see "Q1 Launch"
    And I should see "Mobile App"
    # Guest should not see New Project button
    And I should not see "New Project"
    # Navigate to project show - guest should not see kebab menu
    When I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app"
    And I wait for the page to load
    Then "button[aria-label='Actions menu']" should not exist

  # ---------------------------------------------------------------------------
  # Direct URL Access Control
  # ---------------------------------------------------------------------------

  Scenario: Owner can access project edit page directly
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app/edit"
    And I wait for the page to load
    Then "#project-form" should be visible
    And the URL should contain "/projects/mobile-app/edit"

  Scenario: Guest cannot access project edit page directly
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app/edit"
    And I wait for the page to load
    Then I should see "You are not authorized to edit this project"
    And the URL should contain "/workspaces"

  Scenario: Member cannot access edit page for others' projects
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app/edit"
    And I wait for the page to load
    Then I should see "You are not authorized to edit this project"
    And the URL should contain "/workspaces"

  Scenario: Non-member cannot access any project page
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${nonMemberEmail}"
    And I fill "#login_form_password_password" with "${nonMemberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}/projects/mobile-app"
    And I wait for the page to load
    Then I should not see "Mobile App"
