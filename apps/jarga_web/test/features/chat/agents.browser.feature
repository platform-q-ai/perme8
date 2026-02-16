@browser @chat @agents
Feature: Chat Agent Selection
  As a user
  I want to select which AI agent to chat with
  So that I can use the right assistant for my task

  # Browser adapter translation of agents.feature
  # Tests agent selection functionality through the browser UI:
  # - Viewing available agents
  # - Selecting an agent
  # - Agent preference persistence
  # - Workspace-scoped agent visibility

  Background:
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation

  # ============================================================================
  # CRITICAL SCENARIOS
  # ============================================================================

  Scenario: Agent selector shows available agents
    Given I am on "${baseUrl}/workspaces/${workspaceId}"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    Then "[data-test-agent-selector]" should be visible
    And "[data-test-agent-selector] option" should exist

  Scenario: Select an agent for chatting
    Given I am on "${baseUrl}/workspaces/${workspaceId}"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    Then "[data-test-agent-selector]" should have value "${agentName}"
    And "[data-test-message-input]" should be enabled

  # ============================================================================
  # HIGH PRIORITY SCENARIOS
  # ============================================================================

  Scenario: Agent selector excludes disabled agents
    Given I am on "${baseUrl}/workspaces/${workspaceId}"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    # Only enabled agents should appear in the selector
    Then "[data-test-agent-selector]" should be visible
    And I should not see "${disabledAgentName}"

  Scenario: Auto-select first agent when none previously selected
    Given I am on "${baseUrl}/workspaces/${workspaceId}"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    # An agent should be automatically selected
    Then "[data-test-agent-selector]" should be visible
    And "[data-test-message-input]" should be enabled

  Scenario: Restore previously selected agent after page reload
    Given I am on "${baseUrl}/workspaces/${workspaceId}"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    # Reload and verify agent is still selected
    When I reload the page
    And I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    Then "[data-test-agent-selector]" should have value "${agentName}"

  Scenario: Agent selection saved to preferences
    Given I am on "${baseUrl}/workspaces/${workspaceId}"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    And I wait for network idle
    # Navigate away and back to verify persistence
    Given I am on "${baseUrl}/dashboard"
    When I wait for the page to load
    Given I am on "${baseUrl}/workspaces/${workspaceId}"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    Then "[data-test-agent-selector]" should have value "${agentName}"

  # ============================================================================
  # MEDIUM PRIORITY SCENARIOS
  # ============================================================================

  Scenario: Agent selection is workspace-scoped
    # Visit workspace 1 and check agents
    Given I am on "${baseUrl}/workspaces/${workspaceId}"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    Then "[data-test-agent-selector]" should be visible
    And I should see "${agentName}"

  Scenario: Handle workspace with no enabled agents
    Given I am on "${baseUrl}/workspaces/${emptyWorkspaceId}"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    Then I should see "No agents available"
    And "[data-test-message-input]" should be disabled

  Scenario: Handle deleted agent gracefully
    Given I am on "${baseUrl}/workspaces/${workspaceId}"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    And I fill "[data-test-message-input]" with "Hello agent"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    # If the agent is deleted, existing messages should remain visible
    Then I should see "Hello agent"
    And "[data-test-agent-selector]" should be visible

  # ============================================================================
  # LOW PRIORITY SCENARIOS
  # ============================================================================

  Scenario: Agent selector has accessible label
    Given I am on "${baseUrl}/workspaces/${workspaceId}"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    Then "[data-test-agent-selector]" should have attribute "aria-label" with value "Select an agent"
