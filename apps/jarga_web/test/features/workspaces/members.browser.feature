@browser
Feature: Workspace Member Management
  As a workspace admin
  I want to invite and manage workspace members
  So that I can control who has access to the workspace

  # Seed data (from exo_seeds_web.exs) provides:
  #   - Workspace "Product Team" with slug "product-team"
  #   - alice@example.com as owner
  #   - bob@example.com as admin
  #   - charlie@example.com as member
  #   - diana@example.com as guest
  #   - eve@example.com as non-member

  # ---------------------------------------------------------------------------
  # Open Members Modal
  # ---------------------------------------------------------------------------

  Scenario: Admin opens members modal from workspace show
    # Log in as admin
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace and open kebab menu then members modal
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    And I click "button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I click the "Manage Members" button
    And I wait for ".modal.modal-open" to be visible
    Then "#members-list" should be visible
    And I should see "${ownerEmail}"
    And I should see "Owner"

  # ---------------------------------------------------------------------------
  # Invite Members
  # ---------------------------------------------------------------------------

  Scenario: Admin invites new member via modal
    # Log in as admin
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace and open kebab menu then members modal
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    And I click "button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I click the "Manage Members" button
    And I wait for ".modal.modal-open" to be visible
    # Invite eve
    And I fill "[name='email']" with "${nonMemberEmail}"
    And I select "member" from "[name='role']"
    And I click the "Invite" button
    And I wait for network idle
    Then I should see "${nonMemberEmail}"

  Scenario: Member cannot see Manage Members option
    # Log in as member
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace - kebab menu should not exist for members
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then "button[aria-label='Actions menu']" should not exist

  Scenario: Guest cannot see Manage Members option
    # Log in as guest
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace - kebab menu should not exist for guests
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then "button[aria-label='Actions menu']" should not exist

  # ---------------------------------------------------------------------------
  # Change Member Role
  # ---------------------------------------------------------------------------

  Scenario: Admin changes member role
    # Log in as admin
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace and open kebab menu then members modal
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    And I click "button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I click the "Manage Members" button
    And I wait for ".modal.modal-open" to be visible
    # Change charlie's role to admin
    And I select "admin" from "select[phx-value-email='${memberEmail}']"
    And I wait for network idle
    Then I should see "Member role updated successfully"

  Scenario: Owner role is displayed as badge not select
    # Log in as admin
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace and open kebab menu then members modal
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    And I click "button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I click the "Manage Members" button
    And I wait for ".modal.modal-open" to be visible
    # Owner's role selector should not exist - shown as badge instead
    Then "select[phx-value-email='${ownerEmail}']" should not exist
    And I should see "Owner"

  # ---------------------------------------------------------------------------
  # Remove Members
  # ---------------------------------------------------------------------------

  @wip
  Scenario: Admin removes member
    # Tagged @wip because remove button uses native data-confirm browser
    # dialog which Playwright cannot interact with via standard BDD steps.
    # Log in as admin
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace and open kebab menu then members modal
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    And I click "button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I click the "Manage Members" button
    And I wait for ".modal.modal-open" to be visible
    # Verify remove button exists for charlie
    Then "button[phx-value-email='${memberEmail}']" should exist

  Scenario: Owner cannot be removed by admin
    # Log in as admin
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace and open kebab menu then members modal
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    And I click "button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I click the "Manage Members" button
    And I wait for ".modal.modal-open" to be visible
    # Remove button for owner should not exist
    Then "button[phx-value-email='${ownerEmail}']" should not exist

  Scenario: Close members modal with Done button
    # Log in as admin
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Navigate to workspace and open kebab menu then members modal
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    And I click "button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I click the "Manage Members" button
    And I wait for ".modal.modal-open" to be visible
    # Close the modal
    And I click the "Done" button
    And I wait for ".modal.modal-open" to be hidden
    Then "#members-list" should not exist

  # ---------------------------------------------------------------------------
  # Access Control
  # ---------------------------------------------------------------------------

  Scenario: Non-member cannot access workspace
    # Log in as non-member
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for the page to load
    When I fill "#login_form_password_email" with "${nonMemberEmail}"
    And I fill "#login_form_password_password" with "${nonMemberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    # Attempt to navigate to workspace
    And I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for the page to load
    Then the URL should contain "/workspaces"
    And I should see "Workspace not found"
