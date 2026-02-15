@browser @chat @messaging
Feature: Chat Messaging
  As a user
  I want to send messages to AI agents and receive responses
  So that I can get help with my work

  # Browser adapter translation of messaging.feature
  # Tests core messaging functionality through the browser UI:
  # - Sending messages
  # - Receiving responses
  # - Message display and formatting
  # - Basic message management

  Background:
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I select "${agentName}" from "[data-test-agent-selector]"

  # ============================================================================
  # CRITICAL SCENARIOS
  # ============================================================================

  Scenario: Send a message and see it in chat
    When I fill "[data-test-message-input]" with "How do I write a test?"
    And I click the "Send" button
    And I wait for network idle
    Then I should see "How do I write a test?"
    And "[data-test-message-input]" should have value ""

  Scenario: Receive agent response
    When I fill "[data-test-message-input]" with "What is TDD?"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    Then "[data-test-assistant-message]" should be visible
    And I should see "TDD"

  # ============================================================================
  # HIGH PRIORITY SCENARIOS
  # ============================================================================

  Scenario: Send message with Enter key
    When I fill "[data-test-message-input]" with "What is TDD?"
    And I press "Enter"
    And I wait for network idle
    Then I should see "What is TDD?"
    And "[data-test-message-input]" should have value ""

  Scenario: Cannot send empty message
    When I clear "[data-test-message-input]"
    Then "[data-test-send-button]" should be disabled

  Scenario: View message history in chat
    # Send a message and wait for response to build history
    When I fill "[data-test-message-input]" with "What is Clean Architecture?"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    Then I should see "What is Clean Architecture?"
    And "[data-test-assistant-message]" should be visible

  Scenario: Message is persisted after page reload
    When I fill "[data-test-message-input]" with "Hello, agent"
    And I click the "Send" button
    And I wait for network idle
    And I reload the page
    And I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    Then I should see "Hello, agent"

  # ============================================================================
  # MEDIUM PRIORITY SCENARIOS
  # ============================================================================

  Scenario: Shift+Enter creates new line without sending
    When I focus on "[data-test-message-input]"
    And I type "Line 1" into "[data-test-message-input]"
    And I press "Shift+Enter"
    And I type "Line 2" into "[data-test-message-input]"
    Then "[data-test-message-input]" should contain text "Line 1"
    And "[data-test-message-input]" should contain text "Line 2"

  Scenario: Delete a message
    When I fill "[data-test-message-input]" with "Message to delete"
    And I click the "Send" button
    And I wait for network idle
    Then I should see "Message to delete"
    When I click "[data-test-message-delete]"
    And I wait for 1 seconds
    Then I should not see "Message to delete"

  # ============================================================================
  # FORMATTING SCENARIOS
  # ============================================================================

  Scenario: Code blocks displayed with syntax highlighting
    When I fill "[data-test-message-input]" with "Show me an Elixir code example"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    Then "[data-test-assistant-message] pre code" should exist

  Scenario: Markdown rendered as HTML in responses
    When I fill "[data-test-message-input]" with "Give me a heading and a list"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    # Verify markdown is rendered, not raw syntax
    Then "[data-test-assistant-message]" should be visible
    And I should not see "##"

  Scenario: Links rendered as clickable in responses
    When I fill "[data-test-message-input]" with "Give me a link to example.com"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    Then "[data-test-assistant-message] a" should exist
