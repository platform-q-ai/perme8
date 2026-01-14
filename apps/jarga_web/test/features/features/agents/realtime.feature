Feature: Agent Real-time Updates
  As a user
  I want agent changes to propagate in real-time
  So that my team always sees the latest agent configuration

  Background:
    Given I am logged in as a user

  # PubSub Notifications

  Scenario: Agent updates propagate to all connected clients
    Given I have an agent "Team Bot" in workspace "Dev Team"
    And "Alice" is viewing workspace "Dev Team" chat panel
    And "Bob" is viewing workspace "Dev Team" chat panel
    When I update agent "Team Bot" configuration
    Then "Alice" should see the updated agent in her chat panel
    And "Bob" should see the updated agent in his chat panel

  Scenario: Agent deletion removes it from connected clients
    Given I have an agent "Old Bot" in workspace "Dev Team"
    And "Alice" has "Old Bot" selected in the chat panel
    When I delete agent "Old Bot"
    Then "Alice" should see "Old Bot" removed from the agent list
    And if "Old Bot" was her only agent, the chat panel should auto-select another agent

  Scenario: Agent update broadcasts to affected workspaces only
    Given I have an agent "Shared Bot" in workspaces "Team A" and "Team B"
    And "Team A" and "Team B" members are connected
    When I update "Shared Bot" configuration
    Then "Team A" members should receive a workspace agent updated message
    And "Team B" members should receive a workspace agent updated message
    And members of other workspaces should not receive notifications

  Scenario: Agent removal broadcasts to affected workspace
    Given I have an agent "Helper" in workspace "Team A"
    And "Team A" members are connected
    When I remove "Helper" from workspace "Team A"
    Then "Team A" members should receive agent removed notification
    And their chat panels should refresh the agent list

  Scenario: Agent addition broadcasts to affected workspace
    Given I have an agent "Helper"
    And a workspace "Team B" exists
    And "Team B" members are connected
    When I add "Helper" to workspace "Team B"
    Then "Team B" members should receive agent added notification
    And "Helper" should appear in their agent selectors
