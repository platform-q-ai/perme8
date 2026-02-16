@browser @wip
Feature: Agent Real-time Updates
  As a user
  I want agent changes to propagate in real-time
  So that my team always sees the latest agent configuration

  # Seed data: A test user with email "test@example.com" and password "Password123!"
  # must exist. Workspaces and agents are assumed to be seeded.

  # NOTE: Real-time / PubSub scenarios involve multiple concurrent browser sessions.
  # The browser adapter runs as a single user in a single session, so multi-user
  # real-time propagation cannot be fully tested here. These scenarios are simplified
  # to verify the single-user perspective: that after performing an action, the UI
  # reflects the change without requiring a manual page refresh.

  Background:
    Given I am on "${baseUrl}/users/log-in"
    When I fill "[data-testid='email']" with "test@example.com"
    And I fill "[data-testid='password']" with "Password123!"
    And I click the "Log in" button
    And I wait for the page to load

  # PubSub Notifications

  Scenario: Agent updates propagate to all connected clients
    # NOTE: Multi-user real-time propagation cannot be tested in a single browser session.
    # This scenario verifies that after updating an agent, the change is reflected
    # on the agents page without a manual reload (LiveView push).
    # Prerequisite: agent "Team Bot" exists in workspace "Dev Team"
    When I navigate to "${baseUrl}/workspaces/dev-team/agents"
    And I wait for the page to load
    And I click "[data-testid='agent-edit-Team Bot']"
    And I wait for "[data-testid='agent-form']" to be visible
    And I fill "[data-testid='agent-description']" with "Updated description"
    And I click the "Save" button
    And I wait for network idle
    Then I should see "Updated description"

  Scenario: Agent deletion removes it from connected clients
    # NOTE: Multi-user propagation limitation applies.
    # We verify that deleting an agent removes it from the agent list immediately.
    # Prerequisite: agent "Old Bot" exists in workspace "Dev Team"
    When I navigate to "${baseUrl}/workspaces/dev-team/agents"
    And I wait for the page to load
    And I should see "Old Bot"
    And I click "[data-testid='agent-delete-Old Bot']"
    And I wait for "[data-testid='confirm-dialog']" to be visible
    And I click the "Confirm" button
    And I wait for network idle
    Then I should not see "Old Bot"

  Scenario: Agent update broadcasts to affected workspaces only
    # NOTE: Multi-user real-time broadcast testing requires multiple browser sessions.
    # This scenario is simplified to verify that updating an agent in one workspace
    # context shows the update when navigating to that workspace's agent view.
    # Prerequisite: agent "Shared Bot" exists in workspaces "Team A" and "Team B"
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click "[data-testid='agent-edit-Shared Bot']"
    And I wait for "[data-testid='agent-form']" to be visible
    And I fill "[data-testid='agent-description']" with "Broadcast test update"
    And I click the "Save" button
    And I wait for network idle
    When I navigate to "${baseUrl}/workspaces/team-a/agents"
    And I wait for the page to load
    Then I should see "Broadcast test update"
    When I navigate to "${baseUrl}/workspaces/team-b/agents"
    And I wait for the page to load
    Then I should see "Broadcast test update"

  Scenario: Agent removal broadcasts to affected workspace
    # NOTE: Multi-user real-time limitation applies.
    # Verify that removing an agent from a workspace updates the workspace's agent list.
    # Prerequisite: agent "Helper" exists in workspace "Team A"
    When I navigate to "${baseUrl}/workspaces/team-a/agents"
    And I wait for the page to load
    And I should see "Helper"
    And I click "[data-testid='agent-remove-Helper']"
    And I wait for network idle
    Then I should not see "Helper"

  Scenario: Agent addition broadcasts to affected workspace
    # NOTE: Multi-user real-time limitation applies.
    # Verify that adding an agent to a workspace makes it appear in the workspace agent list.
    # Prerequisite: agent "Helper" exists but is not in workspace "Team B"
    When I navigate to "${baseUrl}/workspaces/team-b/settings"
    And I wait for the page to load
    And I click "[data-testid='add-agent-button']"
    And I wait for "[data-testid='agent-picker']" to be visible
    And I click "[data-testid='agent-option-Helper']"
    And I click the "Add" button
    And I wait for network idle
    When I navigate to "${baseUrl}/workspaces/team-b/agents"
    And I wait for the page to load
    Then I should see "Helper"
