@chat @agents
Feature: Chat Agent Selection
  As a user
  I want to select which AI agent to chat with
  So that I can use the right assistant for my task

  # This file covers agent selection functionality:
  # - Viewing available agents
  # - Selecting an agent
  # - Agent preference persistence
  # - Workspace-scoped agent visibility

  Background:
    Given I am logged in as a user

  # ============================================================================
  # CRITICAL SCENARIOS
  # ============================================================================

  @critical @liveview
  Scenario: Agent selector shows available agents
    Given I am in workspace "Dev Team"
    And workspace "Dev Team" has the following enabled agents:
      | Name          | Owner | Visibility |
      | Code Helper   | Alice | SHARED     |
      | My Assistant  | Me    | PRIVATE    |
    When I open the chat panel
    Then the agent selector should list "Code Helper"
    And the agent selector should list "My Assistant"

  @critical @liveview
  Scenario: Select an agent for chatting
    Given the chat panel is open
    And multiple agents are available
    When I select agent "Code Helper" from the dropdown
    Then "Code Helper" should be marked as selected
    And I should be able to send messages to "Code Helper"

  # ============================================================================
  # HIGH PRIORITY SCENARIOS
  # ============================================================================

  @high @liveview
  Scenario: Agent selector excludes disabled agents
    Given I am in workspace "Dev Team"
    And workspace "Dev Team" has enabled agent "Active Bot"
    And workspace "Dev Team" has disabled agent "Old Bot"
    When I open the chat panel
    Then the agent selector should list "Active Bot"
    And the agent selector should not list "Old Bot"

  @high @liveview
  Scenario: Auto-select first agent when none previously selected
    Given I am in workspace "Dev Team"
    And I have no saved agent preference for this workspace
    And workspace has agents "Alpha Bot" and "Beta Bot" in that order
    When I open the chat panel
    Then "Alpha Bot" should be automatically selected

  @high @liveview
  Scenario: Restore previously selected agent
    Given I am in workspace "Dev Team"
    And I previously selected agent "Code Helper" in this workspace
    When I open the chat panel
    Then "Code Helper" should be selected

  @high @liveview
  Scenario: Agent selection saved to preferences
    Given I am in workspace "Dev Team"
    And workspace "Dev Team" has enabled agent "Code Helper"
    And the chat panel is open
    When I select agent "Code Helper"
    Then my agent selection should be saved to preferences
    And when I reload the page, "Code Helper" should still be selected

  # ============================================================================
  # MEDIUM PRIORITY SCENARIOS
  # ============================================================================

  @medium @liveview
  Scenario: Agent selection is workspace-scoped
    Given I am a member of workspaces "Dev Team" and "QA Team"
    And workspace "Dev Team" has agent "Dev Helper"
    And workspace "QA Team" has agent "QA Bot"
    When I view the chat panel in workspace "Dev Team"
    Then I should see "Dev Helper"
    And I should not see "QA Bot"

  @medium @liveview
  Scenario: Different agent selection per workspace
    Given I am in workspace "Dev Team"
    And workspace "Dev Team" has enabled agent "Dev Helper"
    And the chat panel is open
    And I select agent "Dev Helper"
    When I navigate to workspace "QA Team"
    And workspace "QA Team" has enabled agent "QA Bot"
    And I select agent "QA Bot"
    And I navigate back to workspace "Dev Team"
    Then "Dev Helper" should be selected

  @medium @liveview
  Scenario: Handle workspace with no enabled agents
    Given I am in workspace "Empty Team"
    And workspace "Empty Team" has no enabled agents
    When I open the chat panel
    Then I should see a message about no agents available
    And the message input should be disabled

  @medium @liveview
  Scenario: Handle deleted agent gracefully
    Given I had agent "Old Bot" selected
    And I have an active conversation with "Old Bot"
    When "Old Bot" is deleted
    Then my existing messages should still be visible
    And I should be prompted to select a different agent
    And the agent selector should show remaining agents

  # ============================================================================
  # LOW PRIORITY SCENARIOS
  # ============================================================================

  @low @liveview
  Scenario: Agent selector has accessible label
    Given the chat panel is open
    Then the agent selector should have a descriptive label
    And the selector should be keyboard accessible
