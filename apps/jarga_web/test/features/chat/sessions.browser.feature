@browser @chat @sessions
Feature: Chat Session Management
  As a user
  I want to manage my chat conversation history
  So that I can continue previous conversations and organize my AI interactions

  # Browser adapter translation of sessions.feature
  # Tests session management through the browser UI:
  # - Creating new sessions
  # - Viewing conversation history
  # - Loading previous conversations
  # - Deleting conversations
  # - Session restoration

  Background:
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation

  # ============================================================================
  # CRITICAL SCENARIOS
  # ============================================================================

  Scenario: Create new chat session on first message
    When I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    And I fill "[data-test-message-input]" with "Hello"
    And I click the "Send" button
    And I wait for network idle
    Then I should see "Hello"
    And "[data-test-user-message]" should be visible

  Scenario: Messages added to existing session
    When I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    And I fill "[data-test-message-input]" with "First question"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    And I fill "[data-test-message-input]" with "Follow up question"
    And I click the "Send" button
    And I wait for network idle
    Then I should see "First question"
    And I should see "Follow up question"

  # ============================================================================
  # HIGH PRIORITY SCENARIOS
  # ============================================================================

  Scenario: Start new conversation clears chat
    When I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    And I fill "[data-test-message-input]" with "Message in old session"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    When I click the "New" button
    And I wait for 1 seconds
    Then I should not see "Message in old session"

  Scenario: View conversation history
    # Create a conversation first
    When I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    And I fill "[data-test-message-input]" with "Session for history test"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    # Open conversation history
    When I click the "History" button
    And I wait for "[data-test-conversations-list]" to be visible
    Then "[data-test-conversations-list]" should be visible
    And "[data-test-conversation-item]" should exist

  Scenario: Load conversation from history
    # Create a conversation
    When I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    And I fill "[data-test-message-input]" with "TDD conversation"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    # Start a new conversation
    When I click the "New" button
    And I wait for 1 seconds
    # Go to history and click previous conversation
    When I click the "History" button
    And I wait for "[data-test-conversations-list]" to be visible
    And I click "[data-test-conversation-item]"
    And I wait for network idle
    Then I should see "TDD conversation"

  Scenario: Restore most recent session on page reload
    When I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    And I fill "[data-test-message-input]" with "Persistent session message"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    When I reload the page
    And I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    Then I should see "Persistent session message"

  # ============================================================================
  # MEDIUM PRIORITY SCENARIOS
  # ============================================================================

  Scenario: Delete conversation from history
    # Create a conversation
    When I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    And I fill "[data-test-message-input]" with "Conversation to delete"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    # Start new session so we can delete the old one
    When I click the "New" button
    And I wait for 1 seconds
    # Open history and delete
    When I click the "History" button
    And I wait for "[data-test-conversations-list]" to be visible
    And I click "[data-test-conversation-delete]"
    And I wait for 1 seconds
    Then "[data-test-conversation-item]" should not exist

  Scenario: Session title generated from first message
    When I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    And I fill "[data-test-message-input]" with "How do I implement TDD in Elixir?"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    # Check conversation history shows the title
    When I click the "History" button
    And I wait for "[data-test-conversations-list]" to be visible
    Then "[data-test-conversation-item]" should contain text "TDD"

  # ============================================================================
  # LOW PRIORITY SCENARIOS
  # ============================================================================

  Scenario: Empty conversations list shows helpful message
    # Assumes a fresh user with no conversations
    When I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I click the "History" button
    And I wait for 1 seconds
    # If no conversations exist, there should be an empty state message
    Then I should see "No conversations yet"

  Scenario: Delete confirmation dialog for conversations
    # Create a conversation
    When I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"
    And I fill "[data-test-message-input]" with "Important Chat"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    When I click the "New" button
    And I wait for 1 seconds
    When I click the "History" button
    And I wait for "[data-test-conversations-list]" to be visible
    Then "[data-test-conversation-item]" should exist
    And "[data-test-conversation-delete]" should exist
