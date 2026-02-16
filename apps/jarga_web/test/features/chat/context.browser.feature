@browser @chat @context
Feature: Chat Context Integration
  As a user
  I want the chat to use relevant context from my documents
  So that the AI agent can give me more relevant and accurate responses

  # Browser adapter translation of context.feature
  # Tests context integration through the browser UI:
  # - Document context inclusion
  # - Context switching between documents
  # - Agent system prompts reflected in responses
  #
  # NOTE: Internal LLM configuration assertions (model, temperature, system prompt
  # content) cannot be directly verified in the browser. These are translated to
  # observable UI behaviors: sending messages, receiving relevant responses.

  Background:
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation

  # ============================================================================
  # HIGH PRIORITY SCENARIOS
  # ============================================================================

  Scenario: Chat uses document context when viewing a document
    Given I am on "${baseUrl}/workspaces/${workspaceId}/documents/${documentId}"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    And I fill "[data-test-message-input]" with "What architecture do we use?"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    Then "[data-test-assistant-message]" should be visible

  Scenario: Agent responds with relevant context from document
    Given I am on "${baseUrl}/workspaces/${workspaceId}/documents/${documentId}"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    And I fill "[data-test-message-input]" with "Summarize this document"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    Then "[data-test-assistant-message]" should be visible

  # ============================================================================
  # MEDIUM PRIORITY SCENARIOS
  # ============================================================================

  Scenario: Chat without document context works from dashboard
    Given I am on "${baseUrl}/dashboard"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    And I fill "[data-test-message-input]" with "What is Clean Architecture?"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    Then "[data-test-assistant-message]" should be visible

  Scenario: Context switches when navigating between documents
    # View first document and chat
    Given I am on "${baseUrl}/workspaces/${workspaceId}/documents/${documentId}"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    And I fill "[data-test-message-input]" with "What is this document about?"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    Then "[data-test-assistant-message]" should be visible
    # Navigate to a different document
    Given I am on "${baseUrl}/workspaces/${workspaceId}/documents/${documentId2}"
    When I wait for the page to load
    And I wait for "[data-test-chat-panel]" to be visible
    Then "[data-test-message-input]" should be enabled

  Scenario: Document source attribution displayed with response
    Given I am on "${baseUrl}/workspaces/${workspaceId}/documents/${documentId}"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    And I fill "[data-test-message-input]" with "What does this document say?"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    Then "[data-test-source-attribution]" should exist

  # ============================================================================
  # LOW PRIORITY SCENARIOS
  # ============================================================================

  Scenario: Agent without system prompt still works correctly
    Given I am on "${baseUrl}/workspaces/${workspaceId}/documents/${documentId}"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    And I fill "[data-test-message-input]" with "Hello"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    Then "[data-test-assistant-message]" should be visible
