@browser @wip
Feature: Agent Workspace Assignment
  As a user
  I want to add and remove agents from workspaces
  So that I can share AI assistants with my team

  # Seed data: A test user with email "test@example.com" and password "Password123!"
  # must exist. Workspaces and agents are assumed to be seeded as needed per scenario.

  Background:
    Given I am on "${baseUrl}/users/log-in"
    When I fill "[data-testid='email']" with "test@example.com"
    And I fill "[data-testid='password']" with "Password123!"
    And I click the "Log in" button
    And I wait for the page to load

  # Adding Agents to Workspaces

  Scenario: Add my private agent to a workspace I belong to
    # Prerequisite: workspace "Dev Team" exists, user is a member, agent "Code Helper" (PRIVATE) exists
    When I navigate to "${baseUrl}/workspaces/dev-team/settings"
    And I wait for the page to load
    And I click "[data-testid='add-agent-button']"
    And I wait for "[data-testid='agent-picker']" to be visible
    And I click "[data-testid='agent-option-Code Helper']"
    And I click the "Add" button
    And I wait for network idle
    Then I should see "Code Helper"

  Scenario: Add my shared agent to a workspace
    # Prerequisite: workspace "Dev Team" exists, user is a member, agent "Team Assistant" (SHARED) exists
    When I navigate to "${baseUrl}/workspaces/dev-team/settings"
    And I wait for the page to load
    And I click "[data-testid='add-agent-button']"
    And I wait for "[data-testid='agent-picker']" to be visible
    And I click "[data-testid='agent-option-Team Assistant']"
    And I click the "Add" button
    And I wait for network idle
    Then I should see "Team Assistant"

  Scenario: Cannot add agent to workspace I'm not a member of
    # NOTE: The UI should not show workspaces the user is not a member of.
    # We verify by navigating to the workspace settings and expecting an error/redirect.
    When I navigate to "${baseUrl}/workspaces/other-team/settings"
    And I wait for the page to load
    Then I should not see "Add Agent"

  Scenario: Cannot add another user's agent to a workspace
    # NOTE: Multi-user scenario. Another user's agents should not appear in the agent picker.
    When I navigate to "${baseUrl}/workspaces/dev-team/settings"
    And I wait for the page to load
    And I click "[data-testid='add-agent-button']"
    And I wait for "[data-testid='agent-picker']" to be visible
    Then I should not see "Their Agent"

  Scenario: Remove agent from workspace
    # Prerequisite: agent "Code Helper" is already added to workspace "Dev Team"
    When I navigate to "${baseUrl}/workspaces/dev-team/settings"
    And I wait for the page to load
    And I click "[data-testid='agent-remove-Code Helper']"
    And I wait for network idle
    Then I should not see "Code Helper"

  Scenario: Delete agent removes it from all workspaces
    # Prerequisite: agent "Shared Helper" is added to workspaces "Project A" and "Project B"
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click "[data-testid='agent-delete-Shared Helper']"
    And I wait for "[data-testid='confirm-dialog']" to be visible
    And I click the "Confirm" button
    And I wait for network idle
    When I navigate to "${baseUrl}/workspaces/project-a/agents"
    And I wait for the page to load
    Then I should not see "Shared Helper"
    When I navigate to "${baseUrl}/workspaces/project-b/agents"
    And I wait for the page to load
    Then I should not see "Shared Helper"

  Scenario: Update agent and notify affected workspaces
    # NOTE: Multi-user notification cannot be verified in a single browser session.
    # We verify that the update is visible when navigating to each workspace.
    # Prerequisite: agent "Team Assistant" is added to workspaces "Dev Team" and "QA Team"
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click "[data-testid='agent-edit-Team Assistant']"
    And I wait for "[data-testid='agent-form']" to be visible
    And I fill "[data-testid='agent-system-prompt']" with "Updated system prompt"
    And I click the "Save" button
    And I wait for network idle
    When I navigate to "${baseUrl}/workspaces/dev-team/agents"
    And I wait for the page to load
    Then I should see "Team Assistant"
    When I navigate to "${baseUrl}/workspaces/qa-team/agents"
    And I wait for the page to load
    Then I should see "Team Assistant"

  # Workspace Synchronization

  Scenario: Sync agent workspaces adds to new workspaces
    # Prerequisite: agent "My Helper" is in workspaces "Team A" and "Team B"
    # We add "Team C" via the agent's workspace assignment UI.
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click "[data-testid='agent-edit-My Helper']"
    And I wait for "[data-testid='agent-form']" to be visible
    And I check "[data-testid='workspace-checkbox-Team C']"
    And I click the "Save" button
    And I wait for network idle
    When I navigate to "${baseUrl}/workspaces/team-c/agents"
    And I wait for the page to load
    Then I should see "My Helper"
    When I navigate to "${baseUrl}/workspaces/team-a/agents"
    And I wait for the page to load
    Then I should see "My Helper"

  Scenario: Sync agent workspaces removes from old workspaces
    # Prerequisite: agent "My Helper" is in workspaces "Team A", "Team B", and "Team C"
    # We uncheck "Team B" via the agent's workspace assignment UI.
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click "[data-testid='agent-edit-My Helper']"
    And I wait for "[data-testid='agent-form']" to be visible
    And I uncheck "[data-testid='workspace-checkbox-Team B']"
    And I click the "Save" button
    And I wait for network idle
    When I navigate to "${baseUrl}/workspaces/team-b/agents"
    And I wait for the page to load
    Then I should not see "My Helper"
    When I navigate to "${baseUrl}/workspaces/team-a/agents"
    And I wait for the page to load
    Then I should see "My Helper"

  Scenario: Sync agent workspaces with no changes is idempotent
    # Prerequisite: agent "My Helper" is in workspaces "Team A" and "Team B"
    # We open the edit form and save without changes.
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    And I click "[data-testid='agent-edit-My Helper']"
    And I wait for "[data-testid='agent-form']" to be visible
    And I click the "Save" button
    And I wait for network idle
    When I navigate to "${baseUrl}/workspaces/team-a/agents"
    And I wait for the page to load
    Then I should see "My Helper"
    When I navigate to "${baseUrl}/workspaces/team-b/agents"
    And I wait for the page to load
    Then I should see "My Helper"

  # Agent Selection and Persistence

  Scenario: Select agent for workspace persists in user preferences
    # Prerequisite: workspace "Dev Team" has agents "Helper A" and "Helper B"
    When I navigate to "${baseUrl}/workspaces/dev-team/chat"
    And I wait for the page to load
    And I click "[data-testid='agent-selector']"
    And I click "[data-testid='agent-option-Helper A']"
    And I wait for network idle
    And I reload the page
    And I wait for the page to load
    Then "[data-testid='agent-selector']" should contain text "Helper A"

  Scenario: Different agent selection per workspace
    # Prerequisite: user is a member of "Dev Team" (with "Dev Helper") and "QA Team" (with "QA Bot")
    When I navigate to "${baseUrl}/workspaces/dev-team/chat"
    And I wait for the page to load
    And I click "[data-testid='agent-selector']"
    And I click "[data-testid='agent-option-Dev Helper']"
    And I wait for network idle
    When I navigate to "${baseUrl}/workspaces/qa-team/chat"
    And I wait for the page to load
    And I click "[data-testid='agent-selector']"
    And I click "[data-testid='agent-option-QA Bot']"
    And I wait for network idle
    When I navigate to "${baseUrl}/workspaces/dev-team/chat"
    And I wait for the page to load
    Then "[data-testid='agent-selector']" should contain text "Dev Helper"
    When I navigate to "${baseUrl}/workspaces/qa-team/chat"
    And I wait for the page to load
    Then "[data-testid='agent-selector']" should contain text "QA Bot"

  Scenario: Auto-select first agent when no preference exists
    # Prerequisite: workspace "Dev Team" has agents "Alpha", "Beta", "Gamma";
    # user has no saved agent preference for this workspace.
    When I navigate to "${baseUrl}/workspaces/dev-team/chat"
    And I wait for the page to load
    Then "[data-testid='agent-selector']" should contain text "Alpha"

  # Clone from Workspace Context

  Scenario: Clone a shared agent from workspace context
    # Prerequisite: another user's shared agent "Team Helper" is in workspace "Dev Team"
    When I navigate to "${baseUrl}/workspaces/dev-team/agents"
    And I wait for the page to load
    And I click "[data-testid='agent-clone-Team Helper']"
    And I wait for network idle
    Then I should see "Team Helper (Copy)"

  Scenario: Cannot clone agent without workspace context if not owner
    # NOTE: Multi-user scenario. Without workspace context, another user's shared
    # agent should not have a clone option available.
    When I navigate to "${baseUrl}/agents"
    And I wait for the page to load
    Then "[data-testid='agent-clone-Public Helper']" should not exist
