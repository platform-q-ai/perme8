@chat @editor
Feature: Chat Editor Integration
  As a user
  I want to invoke AI agents directly from the document editor
  So that I can get AI assistance without leaving my editing context

  # This file covers editor integration:
  # - @j command for inline agent queries
  # - Inserting chat responses into notes
  # - Agent response rendering in editor
  # - Error handling for editor commands

  Background:
    Given I am logged in as a user
    And I have a workspace with an enabled agent

  # ============================================================================
  # HIGH PRIORITY SCENARIOS
  # ============================================================================

  @fix3 @high @javascript
  Scenario: Execute agent query with @j command
    Given I am editing a document in a workspace
    And workspace has an agent named "code-helper"
    When I type "@j code-helper How do I write a test?" in the editor
    And I press Enter
    Then the agent query should be executed
    And the response should stream into the document
    And the response should be inserted at the cursor position

  @fix1 @high @javascript
  Scenario: Agent query uses document content as context
    Given I am editing a document with content:
      """
      # Product Requirements
      Feature: User authentication
      """
    And workspace has an agent named "analyzer"
    When I execute "@j analyzer What features are described?"
    Then the agent should receive the document content as context
    And the response should reference "user authentication"

  @fix4 @high @javascript
  Scenario: Valid agent invocation with mocked response
    Given I am editing a document in a workspace
    And workspace has an enabled agent named "prd-agent"
    When I type "@j prd-agent What is a PRD?" in the editor
    And I press Enter
    And I wait for the agent response to complete
    Then the editor should contain a response about PRD

  # ============================================================================
  # MEDIUM PRIORITY SCENARIOS
  # ============================================================================
  # NOTE: The following scenarios are tagged @ignore because they require
  # full browser automation (Wallaby) to test @j command execution in the
  # Milkdown editor. They involve JavaScript-heavy features that cannot be
  # tested with Phoenix.LiveViewTest alone. These should be implemented when
  # the @javascript test infrastructure is fully operational.
  # ============================================================================

@ignore @medium @javascript
#   Scenario: Invalid @j command format shows error
#     Given I am editing a document
#     When I type "@j" without an agent name or question
#     And I press Enter
#     Then I should see an error about invalid command format
#     And no agent query should be executed
# 
@ignore @medium @javascript
#   Scenario: Non-existent agent shows error
#     Given I am editing a document in a workspace
#     And the workspace has no agent named "fake-agent"
#     When I execute "@j fake-agent What is this?"
#     Then I should see an error "Agent not found"
#     And no query should be executed
# 
@ignore @medium @javascript
#   Scenario: Disabled agent shows error
#     Given I am editing a document in a workspace
#     And workspace has a disabled agent named "old-bot"
#     When I execute "@j old-bot Help me"
#     Then I should see an error "Agent is disabled"
#     And no query should be executed
# 
@ignore @medium @javascript
#   Scenario: Cancel in-document agent query
#     Given I am editing a document
#     And I execute "@j analyzer Explain this document in detail"
#     And the agent starts streaming a response
#     When I trigger the cancel action
#     Then the streaming should stop
#     And the partial response should remain in the document
# 
@ignore @medium @javascript
#   Scenario: Multiple agent queries in same document
#     Given I am editing a document
#     When I execute "@j helper-1 First question"
#     And I wait for the response to complete
#     And I execute "@j helper-2 Second question"
#     Then both responses should be present in the document
#     And the responses should not interfere with each other
# 
@ignore @medium @javascript
#   Scenario: Insert chat response into document note
#     Given I am editing a document with a note
#     And I have an assistant message "Use dependency injection"
#     When I click "Insert into note" on the message
#     Then "Use dependency injection" should be inserted at cursor
#     And the note should be saved
# 
@ignore @medium @javascript
#   Scenario: Agent thinking indicator while waiting
#     Given I am editing a document
#     When I execute "@j analyzer Analyze this document"
#     Then I should see "Agent thinking..." indicator
#     And the indicator should have loading animation styling
# 
@ignore @medium @javascript
#   Scenario: Agent response converted to editable markdown
#     Given an agent streams a response containing:
#       """
#       ## Solution
#       Use **dependency injection**
#       """
#     When the streaming completes
#     Then the content should be parsed as markdown
#     And "Solution" should be a heading
#     And "dependency injection" should be bold
#     And the content should be editable
# 
@ignore @medium @javascript
#   Scenario: Agent error displayed inline in editor
#     Given I execute an agent query
#     When the agent returns an error "API timeout"
#     Then I should see "[Agent Error: API timeout]" in the editor
#     And the error should be styled in red
#     And I can delete the error and continue editing
# 
  # ============================================================================
  # LOW PRIORITY SCENARIOS
  # ============================================================================

  @low @liveview
  Scenario: Insert button only visible on document pages
    Given I am on the dashboard page
    And I have messages in the chat panel
    Then message insert buttons should not be visible
    When I navigate to a document with a note
    Then message insert buttons should be visible

  @fix5 @low @javascript
  Scenario: Completed agent response becomes regular text
    Given an agent has completed a response "Use Clean Architecture"
    When I click in the middle of the response text
    Then my cursor should position correctly
    And I should be able to edit the text normally

  @fix2 @low @javascript
  Scenario: Insert markdown content preserves formatting
    Given I am editing a document with a note
    And I have an assistant message with markdown:
      """
      ## Solution
      Use **dependency injection** for better *testability*.
      """
    When I click "Insert into note" on the message
    Then the heading should be preserved
    And bold and italic formatting should be preserved
