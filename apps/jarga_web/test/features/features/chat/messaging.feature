@chat @messaging
Feature: Chat Messaging
  As a user
  I want to send messages to AI agents and receive responses
  So that I can get help with my work

  # This file covers the core messaging functionality:
  # - Sending messages
  # - Receiving responses
  # - Message display and persistence
  # - Basic message management

  Background:
    Given I am logged in as a user
    And I have a workspace with an enabled agent
    And the chat panel is open
    And an agent is selected

  # ============================================================================
  # CRITICAL SCENARIOS
  # ============================================================================

  @critical @liveview
  Scenario: Send a message and see it in chat
    When I type "How do I write a test?" in the message input
    And I submit the message
    Then my message "How do I write a test?" should appear in the chat
    And the message should be displayed with user styling
    And the message input should be cleared

  @critical @liveview
  Scenario: Message is saved to database
    When I send the message "Hello, agent"
    Then the message should be persisted to the database
    And the message should have role "user"
    And the message should be associated with the current session

  @critical @liveview
  Scenario: Receive agent response
    Given I send the message "What is TDD?"
    When the agent responds with "TDD is Test-Driven Development..."
    Then the agent response should appear below my message
    And the response should be displayed with assistant styling
    And the response should be saved to the database

  # ============================================================================
  # HIGH PRIORITY SCENARIOS
  # ============================================================================

  @high @liveview
  Scenario: Send message with Enter key
    Given I have typed "What is TDD?" in the message input
    When I press Enter
    Then the message should be sent
    And the input field should be cleared

  @high @liveview
  Scenario: Cannot send empty message
    Given the message input is empty
    Then the Send button should be disabled
    When I try to submit the form
    Then no message should be sent

  @high @liveview
  Scenario: View message history in chat
    Given I have a chat session with the following messages:
      | Role      | Content                    |
      | user      | What is Clean Architecture |
      | assistant | Clean Architecture is...   |
      | user      | Can you give an example    |
      | assistant | Here is an example...      |
    When I view the chat panel with session loaded
    Then I should see all 4 messages in chronological order
    And user messages should be right-aligned
    And assistant messages should be left-aligned

  @high @liveview
  Scenario: Messages display timestamps
    Given I have sent a message
    When I view the message in the chat
    Then the message should display its timestamp
    And the timestamp should show relative time

  # ============================================================================
  # MEDIUM PRIORITY SCENARIOS
  # ============================================================================

  @medium @javascript
  Scenario: Shift+Enter creates new line without sending
    Given I have typed "Line 1" in the message input
    When I press Shift+Enter
    And I type "Line 2"
    Then the input should contain both lines
    And the message should not be sent

  @medium @liveview
  Scenario: Delete a message
    Given I have a saved message in the chat
    When I click the delete button on the message
    And I confirm the message deletion
    Then the message should be removed from the chat
    And the message should be deleted from the database

  @medium @liveview
  Scenario: Delete button only appears for saved messages
    Given I have a saved message with a database ID
    Then the message should show a delete option
    Given I have an unsaved message without a database ID
    Then the message should not show a delete option

  @medium @liveview
  Scenario: Cannot delete message from non-existent session
    Given I have a message ID that no longer exists
    When I attempt to delete the invalid message
    Then I should see an error "Message not found"

  # ============================================================================
  # LOW PRIORITY SCENARIOS
  # ============================================================================

  @low @liveview
  Scenario: Delete message shows confirmation dialog
    Given I have a saved message in the chat
    When I click the delete button
    Then I should see a confirmation prompt
    When I cancel the deletion
    Then the message should remain in the chat

  @low @liveview
  Scenario: Message delete button has accessible styling
    Given I have a saved message in the chat
    Then the delete button should have text-error styling
    And the delete button should have aria-label for accessibility


  # Formatting (merged from chat_formatting.feature)

Scenario: Code blocks displayed with syntax highlighting
    Given I receive an assistant message containing:
      """
      ```elixir
      def hello do
        IO.puts("Hello, World!")
      end
      ```
      """
    Then the code should be displayed in a code block element
    And the code block should have syntax highlighting classes

  @low @liveview
  Scenario: Markdown headings rendered as HTML
    Given I receive an assistant message containing:
      """
      # Main Heading
      ## Subheading
      ### Sub-subheading
      """
    Then I should see an h1 element with "Main Heading"
    And I should see an h2 element with "Subheading"
    And I should see an h3 element with "Sub-subheading"
    And I should not see raw "#" markdown syntax

  @low @liveview
  Scenario: Bold and italic text rendered correctly
    Given I receive an assistant message "This is **bold** and *italic* text"
    Then "bold" should be wrapped in a strong tag
    And "italic" should be wrapped in an em tag
    And I should not see asterisks in the rendered output

  @low @liveview
  Scenario: Ordered and unordered lists rendered
    Given I receive an assistant message containing:
      """
      Steps:
      1. First step
      2. Second step

      Features:
      - Feature A
      - Feature B
      """
    Then I should see an ordered list with 2 items
    And I should see an unordered list with 2 items
    And list items should be properly nested

  @low @liveview
  Scenario: Links rendered as clickable
    Given I receive an assistant message "Check out [OpenAI](https://openai.com)"
    Then I should see a clickable link with text "OpenAI"
    And the link should have href "https://openai.com"
    And the link should open in a new tab

  @low @liveview
  Scenario: Blockquotes rendered with styling
    Given I receive an assistant message containing:
      """
      > This is a quote
      > from the documentation
      """
    Then the text should be in a blockquote element
    And the blockquote should have distinctive styling

  @low @liveview
  Scenario: Complex markdown renders all elements
    Given I receive an assistant message containing:
      """
      ## Solution

      Here's how to fix it:

      1. **Install** dependencies
      2. *Configure* settings
      3. Test with:

      ```javascript
      console.log('Hello');
      ```

      See [docs](https://example.com) for more.
      """
    Then the heading should be rendered
    And the list should be rendered
    And bold and italic text should be rendered
    And the code block should be rendered
    And the link should be rendered
    And no raw markdown syntax should be visible