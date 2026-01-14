Feature: Agent Workspace Assignment
  As a user
  I want to add and remove agents from workspaces
  So that I can share AI assistants with my team

  Background:
    Given I am logged in as a user

  # Adding Agents to Workspaces

  Scenario: Add my private agent to a workspace I belong to
    Given I have a workspace named "Dev Team"
    And I am a member of workspace "Dev Team"
    And I have a private agent named "Code Helper"
    When I navigate to workspace "Dev Team" settings
    And I add agent "Code Helper" to the workspace
    Then "Code Helper" should appear in the workspace agents list
    And other workspace members should not see "Code Helper" because it's PRIVATE

  Scenario: Add my shared agent to a workspace
    Given I have a workspace named "Dev Team"
    And I am a member of workspace "Dev Team"
    And I have a shared agent named "Team Assistant"
    When I navigate to workspace "Dev Team" settings
    And I add agent "Team Assistant" to the workspace
    Then "Team Assistant" should appear in the workspace agents list
    And all workspace members should be able to use "Team Assistant"

  Scenario: Cannot add agent to workspace I'm not a member of
    Given there is a workspace named "Other Team"
    And I am not a member of workspace "Other Team"
    And I have an agent named "My Assistant"
    When I attempt to add "My Assistant" to workspace "Other Team"
    Then the sync should succeed
    But the agent should not be added to the workspace

  Scenario: Cannot add another user's agent to a workspace
    Given I am a member of workspace "Dev Team"
    And another user has created an agent named "Their Agent"
    When I attempt to add "Their Agent" to workspace "Dev Team"
    Then I should see an error "not_found"
    And the agent should not be added to the workspace

  Scenario: Remove agent from workspace
    Given I have an agent named "Code Helper"
    And "Code Helper" is added to workspace "Dev Team"
    And I am a member of workspace "Dev Team"
    When I navigate to workspace "Dev Team" settings
    And I remove agent "Code Helper" from the workspace
    Then "Code Helper" should not appear in workspace agents list
    And workspace members should receive notification of removal

  Scenario: Delete agent removes it from all workspaces
    Given I have an agent named "Shared Helper" added to workspaces:
      | Workspace Name |
      | Project A      |
      | Project B      |
    When I delete the agent "Shared Helper"
    Then the agent should be removed from workspace "Project A"
    And the agent should be removed from workspace "Project B"
    And workspace members should receive notifications of the removal

  Scenario: Update agent and notify affected workspaces
    Given I have an agent named "Team Assistant" added to workspaces:
      | Workspace Name |
      | Dev Team       |
      | QA Team        |
    When I update the agent "Team Assistant" with a new system prompt
    Then workspace "Dev Team" members should see the updated agent
    And workspace "QA Team" members should see the updated agent
    And the chat panel in both workspaces should reflect the changes

  # Workspace Synchronization

  Scenario: Sync agent workspaces adds to new workspaces
    Given I have an agent "My Helper"
    And "My Helper" is in workspaces "Team A" and "Team B"
    When I sync agent workspaces to include "Team A", "Team B", and "Team C"
    Then "My Helper" should be added to workspace "Team C"
    And "My Helper" should remain in "Team A" and "Team B"

  Scenario: Sync agent workspaces removes from old workspaces
    Given I have an agent "My Helper"
    And "My Helper" is in workspaces "Team A", "Team B", and "Team C"
    When I sync agent workspaces to only "Team A" and "Team C"
    Then "My Helper" should be removed from workspace "Team B"
    And "My Helper" should remain in "Team A" and "Team C"
    And workspace "Team B" members should receive PubSub notification

  Scenario: Sync agent workspaces with no changes is idempotent
    Given I have an agent "My Helper"
    And "My Helper" is in workspaces "Team A" and "Team B"
    When I sync agent workspaces to only "Team A" and "Team B"
    Then no workspace associations should be added or removed
    And no PubSub notifications should be sent

  # Agent Selection and Persistence

  Scenario: Select agent for workspace persists in user preferences
    Given I am in workspace "Dev Team"
    And workspace has agents "Helper A" and "Helper B"
    When I select agent "Helper A" in the chat panel
    Then my selection should be saved to user preferences
    And when I return to workspace "Dev Team" later, "Helper A" should still be selected

  Scenario: Different agent selection per workspace
    Given I am a member of workspaces "Dev Team" and "QA Team"
    When I select agent "Dev Helper" in workspace "Dev Team"
    And I navigate to workspace "QA Team"
    And I select agent "QA Bot" in workspace "QA Team"
    Then workspace "Dev Team" should remember "Dev Helper" as my selection
    And workspace "QA Team" should remember "QA Bot" as my selection

  Scenario: Auto-select first agent when no preference exists
    Given I am in workspace "Dev Team"
    And workspace has agents "Alpha", "Beta", "Gamma"
    And I have no saved agent preference for this workspace
    When I open the chat panel
    Then agent "Alpha" should be auto-selected
    And the selection should be saved to my preferences

  # Clone from Workspace Context

  Scenario: Clone a shared agent from workspace context
    Given there is a workspace named "Dev Team"
    And I am a member of workspace "Dev Team"
    And another user has a shared agent named "Team Helper" in the workspace
    When I clone "Team Helper" from the workspace context
    Then a new agent "Team Helper (Copy)" should be created
    And the cloned agent should belong to me
    And the cloned agent should have visibility "PRIVATE"
    And the cloned agent should not be in any workspaces

  Scenario: Cannot clone agent without workspace context if not owner
    Given another user has a shared agent named "Public Helper"
    And I am not in a workspace with "Public Helper"
    When I attempt to clone "Public Helper" without workspace context
    Then the clone operation should fail with "forbidden"
    And the agent should not be cloned
