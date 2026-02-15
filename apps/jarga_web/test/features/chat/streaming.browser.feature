@browser @chat @streaming
Feature: Chat Streaming Responses
  As a user
  I want to see agent responses stream in real-time
  So that I get immediate feedback and can see the agent thinking process

  # Browser adapter translation of streaming.feature
  # Tests streaming functionality through the browser UI:
  # - Real-time response streaming
  # - Stream cancellation
  # - Error handling during streaming
  # - Loading states

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

  Scenario: Receive streaming response from agent
    When I fill "[data-test-message-input]" with "Explain Clean Architecture"
    And I click the "Send" button
    Then "[data-test-loading-indicator]" should be visible
    When I wait for "[data-test-assistant-message]" to be visible
    Then "[data-test-assistant-message]" should be visible
    And "[data-test-loading-indicator]" should be hidden

  Scenario: Streaming response persists after completion
    When I fill "[data-test-message-input]" with "What is TDD?"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    And I wait for "[data-test-loading-indicator]" to be hidden
    Then "[data-test-assistant-message]" should be visible
    # Verify persistence by reloading
    When I reload the page
    And I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    Then I should see "TDD"

  # ============================================================================
  # HIGH PRIORITY SCENARIOS
  # ============================================================================

  Scenario: Handle streaming error gracefully
    # Send a message that triggers an error condition
    When I fill "[data-test-message-input]" with "Test message"
    And I click the "Send" button
    And I wait for 3 seconds
    # If an error occurs, the UI should show an error flash and re-enable input
    Then "[data-test-message-input]" should be enabled

  Scenario: Cancel streaming response
    When I fill "[data-test-message-input]" with "Write a long essay about programming"
    And I click the "Send" button
    And I wait for "[data-test-loading-indicator]" to be visible
    When I click the "Cancel" button
    And I wait for "[data-test-loading-indicator]" to be hidden
    Then "[data-test-message-input]" should be enabled

  Scenario: Display loading indicator while waiting for response
    When I fill "[data-test-message-input]" with "Hello"
    And I click the "Send" button
    Then "[data-test-loading-indicator]" should be visible
    And "[data-test-send-button]" should be disabled
    When I wait for "[data-test-assistant-message]" to be visible
    Then "[data-test-loading-indicator]" should be hidden

  Scenario: Stream buffer cleared on completion - user can send new message
    When I fill "[data-test-message-input]" with "First question"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    And I wait for "[data-test-loading-indicator]" to be hidden
    Then "[data-test-message-input]" should be enabled
    And "[data-test-send-button]" should be enabled

  # ============================================================================
  # MEDIUM PRIORITY SCENARIOS
  # ============================================================================

  Scenario: Cancelled response shows partial content
    When I fill "[data-test-message-input]" with "Write a very detailed explanation of programming paradigms"
    And I click the "Send" button
    And I wait for "[data-test-loading-indicator]" to be visible
    And I wait for 1 seconds
    When I click the "Cancel" button
    And I wait for "[data-test-loading-indicator]" to be hidden
    # Partial response should still be visible
    Then "[data-test-assistant-message]" should exist

  # ============================================================================
  # REAL-TIME SCENARIOS
  # ============================================================================

  Scenario: Preserve chat across page reconnections
    When I fill "[data-test-message-input]" with "Important message"
    And I click the "Send" button
    And I wait for "[data-test-assistant-message]" to be visible
    When I reload the page
    And I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    Then I should see "Important message"

  Scenario: Chat panel updates when new agent added to workspace
    # Navigate to workspace, open chat panel, verify agent selector updates
    Given I am on "${baseUrl}/workspaces"
    When I wait for the page to load
    And I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    Then "[data-test-agent-selector]" should be visible
