@chat @streaming
Feature: Chat Streaming Responses
  As a user
  I want to see agent responses stream in real-time
  So that I get immediate feedback and can see the agent thinking process

  # This file covers streaming functionality:
  # - Real-time response streaming
  # - Stream cancellation
  # - Error handling during streaming
  # - Loading states

  Background:
    Given I am logged in as a user
    And I have a workspace with an enabled agent
    And the chat panel is open
    And an agent is selected

  # ============================================================================
  # CRITICAL SCENARIOS
  # ============================================================================

  @critical @liveview
  Scenario: Receive streaming response from agent
    When I send the message "Explain Clean Architecture"
    Then I should see a loading indicator
    When the agent starts streaming a response
    Then I should see the response text appear incrementally
    When the streaming completes
    Then the full response should be displayed
    And the loading indicator should be removed

  @critical @liveview
  Scenario: Streaming response saved to database on completion
    Given I send a message "What is TDD?"
    When the agent streams a complete response "TDD is Test-Driven Development"
    Then the response should be saved to the database
    And the response should have role "assistant"
    And the response should be associated with my session

  # ============================================================================
  # HIGH PRIORITY SCENARIOS
  # ============================================================================

  @high @liveview
  Scenario: Handle streaming error gracefully
    Given I send a message "Test message"
    When the LLM service returns an error "API timeout"
    Then I should see an error flash message containing "Chat error"
    And the loading indicator should be removed
    And the message input should be re-enabled
    And I should be able to send another message

  @high @liveview
  Scenario: Cancel streaming response
    Given I send a message "Write a long essay about programming"
    And the agent starts streaming a response
    When I click the Cancel button
    Then the streaming should stop
    And the partial response should be visible
    And the message input should be re-enabled

  @high @liveview
  Scenario: Streaming chunks update display in real-time
    Given I send a message "Hello"
    When the LLM sends chunk "Hello"
    Then I should see "Hello" in the response area
    When the LLM sends chunk " world"
    Then I should see "Hello world" in the response area
    When the LLM sends done signal
    Then the complete message should be finalized

  @high @liveview
  Scenario: Stream buffer cleared on completion
    Given I send a message and receive a streaming response
    When the streaming completes
    Then the stream buffer should be empty
    And the streaming state should be false
    And I should be able to start a new conversation

  # ============================================================================
  # MEDIUM PRIORITY SCENARIOS
  # ============================================================================

  @medium @liveview
  Scenario: Display loading indicator while waiting for response
    When I send a message "Hello"
    Then I should see "Thinking..." or a loading indicator
    And the send button should be disabled during streaming

  @medium @liveview
  Scenario: Document source attribution displayed with response
    Given I am viewing a document titled "Project Specs"
    When I send a message and receive a response
    Then I should see "Source: Project Specs" below the response
    And the source should be a clickable link

  @medium @liveview
  Scenario: Cancelled response shows cancelled indicator
    Given I send a message and the agent starts streaming
    When I cancel the streaming
    Then the partial response should show a cancelled indicator
    And the partial response should be preserved

  @medium @liveview
  Scenario: Handle streaming error mid-response
    Given I send a message
    And the agent has streamed partial content "Here is the"
    When the LLM service sends an error "Connection lost"
    Then I should see the partial content "Here is the"
    And I should see an error flash message
    And the streaming should stop

  # ============================================================================
  # LOW PRIORITY SCENARIOS
  # ============================================================================

  @low @liveview
  Scenario: Loading indicator has appropriate styling
    When I send a message
    Then the loading indicator should have animated styling
    And it should be visually distinct from message content


  # Real-time (merged from chat_realtime.feature)

Scenario: Preserve chat across LiveView reconnections
    Given I have an active chat session with messages
    When the LiveView connection is lost
    And the connection is restored
    Then my chat session should be restored
    And all messages should still be visible
    And I should be able to continue chatting

  # ============================================================================
  # MEDIUM PRIORITY SCENARIOS
  # ============================================================================

  @medium @liveview
  Scenario: Chat panel updates when new agent added to workspace
    Given I am viewing workspace "Dev Team"
    And the chat panel is open
    When another user adds a new agent "New Helper" to the workspace
    Then I should receive a PubSub notification
    And "New Helper" should appear in my agent selector

  @medium @liveview
  Scenario: Chat panel updates when agent is deleted
    Given I have an agent named "Helper Bot"
    And agent "Helper Bot" is selected in the chat panel
    When "Helper Bot" is deleted from the workspace
    Then I should receive a PubSub notification
    And "Helper Bot" should be removed from my agent selector
    And another available agent should be auto-selected

  @medium @liveview
  Scenario: Agent update propagates to chat panel
    Given I am viewing workspace "Dev Team"
    And the chat panel shows agent "Team Bot"
    When "Team Bot" configuration is updated by another user
    Then I should receive a PubSub notification
    And the agent selector should refresh with updated info

  @medium @liveview
  Scenario: Agent selection broadcasts to parent LiveView
    Given I am on a page with a chat panel
    And workspace has an agent named "Code Helper"
    When I select agent "Code Helper"
    Then an "agent-selected" event should be broadcast
    And the parent LiveView should receive the agent ID

  # ============================================================================
  # LOW PRIORITY SCENARIOS
  # ============================================================================

  @low @liveview
  Scenario: Agent deletion with auto-select fallback
    Given "Helper Bot" is my only available agent
    And "Helper Bot" is selected
    When "Helper Bot" is deleted
    Then I should see a message about no agents available
    And the message input should be disabled