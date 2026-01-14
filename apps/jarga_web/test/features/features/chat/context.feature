@chat @context
Feature: Chat Context Integration
  As a user
  I want the chat to use relevant context from my documents
  So that the AI agent can give me more relevant and accurate responses

  # This file covers context integration:
  # - Document context inclusion
  # - Agent system prompts
  # - LLM configuration
  # - Context switching

  Background:
    Given I am logged in as a user
    And I have a workspace with an enabled agent

  # ============================================================================
  # HIGH PRIORITY SCENARIOS
  # ============================================================================

  @high @liveview
  Scenario: Chat uses document context when viewing a document
    Given I am viewing a document with content:
      """
      # Architecture
      Our system uses Clean Architecture with separate layers.
      """
    And the chat panel is open with agent "Helper" selected
    When I send the message "What architecture do we use?"
    Then the LLM request should include the document content
    And the agent can reference "Clean Architecture" in its response

  @high @liveview
  Scenario: Agent system prompt combined with document context
    Given I am viewing a document with content "Product requirements..."
    And agent "Analyzer" has system prompt "You are an expert analyst"
    And "Analyzer" is selected
    When I send a message "What are the requirements?"
    Then the LLM should receive system message containing "You are an expert analyst"
    And the LLM should receive the document content as context

  @high @liveview
  Scenario: Agent configuration affects LLM call
    Given agent "Precise Bot" is configured with:
      | Model       | gpt-4o |
      | Temperature | 0.1    |
    And "Precise Bot" is selected
    When I send a message
    Then the LLM should be called with model "gpt-4o"
    And the LLM should be called with temperature 0.1

  # ============================================================================
  # MEDIUM PRIORITY SCENARIOS
  # ============================================================================

  @medium @liveview
  Scenario: Chat without document context uses only agent prompt
    Given I am on the dashboard with no document open
    And agent "General Helper" is selected
    And "General Helper" has system prompt "You are a helpful assistant"
    When I send a message "What is Clean Architecture?"
    Then the LLM should receive the agent's system prompt
    And no document context should be included

  @medium @liveview
  Scenario: Context switches when changing documents
    Given I am viewing "Document A" with content "Content A"
    And the chat panel is open
    When I navigate to "Document B" with content "Content B"
    Then future chat messages should use "Content B" as context
    And my conversation history should persist

  @medium @liveview
  Scenario: Session scoped to project when available
    Given I have a project "Project X"
    And I am viewing a document in "Project X"
    When I send my first message
    Then the new session should be scoped to "Project X"
    And the session should be scoped to the current workspace

  # ============================================================================
  # LOW PRIORITY SCENARIOS
  # ============================================================================

  @low @liveview
  Scenario: Agent without system prompt works correctly
    Given agent "Basic Bot" has no system prompt
    And "Basic Bot" is selected
    And I am viewing a document with content "Some content"
    When I send a message
    Then the LLM should receive only the document context
    And the request should complete successfully
