@chat @sessions
Feature: Chat Session Management
  As a user
  I want to manage my chat conversation history
  So that I can continue previous conversations and organize my AI interactions

  # This file covers session management:
  # - Creating new sessions
  # - Viewing conversation history
  # - Loading previous conversations
  # - Deleting conversations
  # - Session restoration

  Background:
    Given I am logged in as a user
    And I have a workspace with an enabled agent

  # ============================================================================
  # CRITICAL SCENARIOS
  # ============================================================================

  @critical @liveview
  Scenario: Create new chat session on first message
    Given I have no active chat session
    And the chat panel is open
    When I send my first message "Hello"
    Then a new chat session should be created
    And the session should be associated with my user ID
    And the session should be scoped to the current workspace
    And the message should be saved to the session

  @critical @liveview
  Scenario: Messages added to existing session
    Given I have an active chat session
    And the session has 2 existing messages
    When I send a new message "Follow up question"
    Then the message should be added to the same session
    And the session should now have 3 messages
    And the session updated_at should be updated

  # ============================================================================
  # HIGH PRIORITY SCENARIOS
  # ============================================================================

  @high @liveview
  Scenario: Start new conversation clears chat
    Given I have an active chat session with messages
    When I click the "New" button
    Then the chat display should be cleared
    And the current session should be reset
    And my next message should create a new session

  @high @liveview
  Scenario: View conversation history
    Given I have the following chat sessions:
      | Title                   | Messages | Created     |
      | Clean Architecture Help | 8        | 2 hours ago |
      | TDD Questions           | 5        | 1 day ago   |
      | Feature Planning        | 12       | 3 days ago  |
    When I click the "History" button
    Then I should see the conversations list view
    And I should see all 3 conversations
    And each should show title and message count

  @high @liveview
  Scenario: Load conversation from history
    Given I have a conversation titled "TDD Questions"
    And the conversation has 5 messages
    When I open the conversations view
    And I click on "TDD Questions"
    Then the chat view should display all 5 messages

  @high @liveview
  Scenario: Restore most recent session on mount
    Given I have multiple chat sessions
    And my most recent session is "Current Work"
    When I reload the page and open the chat panel
    Then the "Current Work" session should be loaded
    And all its messages should be displayed

  # ============================================================================
  # MEDIUM PRIORITY SCENARIOS
  # ============================================================================

  @medium @liveview
  Scenario: Delete conversation from history
    Given I have a conversation titled "Old Chat"
    When I open the conversations view
    And I click the delete button on "Old Chat"
    And I confirm the session deletion
    Then "Old Chat" should be removed from the list
    And "Old Chat" should be deleted from the database

  @medium @liveview
  Scenario: Deleting active conversation clears chat view
    Given I am viewing conversation "Current Work"
    When I switch to conversations view
    And I delete "Current Work"
    Then "Current Work" should be removed from the list
    And when I return to chat view the chat should be empty
    And I should have no active session

  @medium @liveview
  Scenario: Deleting inactive conversation preserves active chat
    Given I am viewing conversation "Session A"
    When I switch to conversations view
    And I delete a different conversation "Session B"
    Then "Session B" should be removed from the list
    And when I return to chat view
    Then "Session A" messages should still be visible

  @medium @liveview
  Scenario: Session title generated from first message
    Given I start a new chat session
    When I send the message "How do I implement TDD in Elixir?"
    Then the session title should be derived from the message
    And the title should be truncated if over 255 characters

  @fix9 @medium @javascript
  Scenario: Restore session from localStorage
    Given I have session ID "abc-123" saved in localStorage
    And the session exists in the database
    And I own the session
    When the chat panel mounts
    Then the session should be loaded automatically
    And all messages should be displayed

  @fix10 @medium @javascript
  Scenario: Clear invalid session from localStorage
    Given I have session ID "invalid-xyz" in localStorage
    And that session does not exist in the database
    When the chat panel mounts
    Then localStorage should be cleared
    And I should see an empty chat

  # ============================================================================
  # LOW PRIORITY SCENARIOS
  # ============================================================================

  @low @liveview
  Scenario: Empty conversations list shows helpful message
    Given I have no saved conversations
    When I view the conversation history
    Then I should see "No conversations yet"
    And I should see a "Start chatting" button
    When I click "Start chatting"
    Then I should return to the chat view

  @low @liveview
  Scenario: Conversation history limited to 20 sessions
    Given I have created 25 chat sessions
    When I view the conversation history
    Then I should see only the 20 most recent sessions

  @low @liveview
  Scenario: Delete confirmation dialog for conversations
    Given I am in the conversations view
    And there is a conversation "Important Chat"
    When I click the trash icon on "Important Chat"
    Then I should see a confirmation dialog
    When I cancel
    Then the conversation should remain in the list

  @low @liveview
  Scenario: Delete icon styling on conversation list
    Given I am in the conversations view with 3 conversations
    Then each conversation should display a trash icon button
    And the icon should be positioned on the right side

  @low @liveview
  Scenario: Preserve chat across LiveView reconnections
    Given I have an active chat session with messages
    When the LiveView connection is lost and restored
    Then my chat session should be restored
    And all messages should still be visible
