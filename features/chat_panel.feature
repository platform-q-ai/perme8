Feature: Chat Panel
  As a user
  I want to interact with AI agents through a global chat panel
  So that I can get help and insights while working on documents and projects

  Background:
    Given I am logged in as a user
    And I have at least one enabled agent available

  # Panel Display and Interaction
  Scenario: Open and close chat panel
    Given I am on any page with the admin layout
    When I click the chat toggle button
    Then the chat panel should slide open from the right
    And the panel should display the chat interface
    When I click the close button
    Then the chat panel should slide closed

  Scenario: Chat panel displays on all admin pages
    Given I am viewing the following pages in sequence:
      | Page                    |
      | Dashboard               |
      | Workspace Overview      |
      | Document Editor         |
      | Project Details         |
    When I toggle the chat panel on each page
    Then the chat panel should be accessible on all pages
    And the chat panel should maintain state across page transitions

  Scenario: Chat panel is resizable
    Given the chat panel is open
    And the panel has default width of 384px (24rem)
    When I drag the resize handle to the left
    Then the panel width should increase
    When I drag the resize handle to the right
    Then the panel width should decrease
    And the resized width should be preserved across sessions

  Scenario: Empty chat shows welcome message
    Given the chat panel is open
    And I have no messages in the current session
    Then I should see the welcome icon (chat bubble)
    And I should see "Ask me anything about this document"

  # Agent Selection
  Scenario: Select agent from dropdown
    Given the chat panel is open
    And workspace has agents "Code Helper" and "Doc Writer"
    When I open the agent selector dropdown
    Then I should see "Code Helper" in the list
    And I should see "Doc Writer" in the list
    When I select "Doc Writer"
    Then "Doc Writer" should be marked as selected
    And my selection should be saved to preferences

  Scenario: Agent selector shows workspace-scoped agents
    Given I am in workspace "Dev Team"
    And workspace "Dev Team" has enabled agents:
      | Agent Name    | Owner  | Visibility |
      | Team Helper   | Alice  | SHARED     |
      | My Assistant  | Me     | PRIVATE    |
    And workspace "Dev Team" also has disabled agent "Old Bot"
    When I open the chat panel
    Then the agent selector should show "Team Helper"
    And the agent selector should show "My Assistant"
    And the agent selector should not show "Old Bot"

  Scenario: Auto-select first agent when none selected
    Given I am in workspace "Dev Team"
    And I have no previously selected agent for this workspace
    And workspace has agents "Alpha Bot" and "Beta Bot"
    When I open the chat panel
    Then "Alpha Bot" should be automatically selected

  Scenario: Restore previously selected agent
    Given I am in workspace "Dev Team"
    And I previously selected agent "Code Helper"
    When I open the chat panel
    Then "Code Helper" should be selected
    And I can start chatting immediately

  Scenario: Agent selection persists across workspace visits
    Given I am in workspace "Dev Team"
    When I select agent "Dev Helper" in the chat panel
    And I navigate to workspace "QA Team"
    And I select agent "QA Bot" in the chat panel
    And I navigate back to workspace "Dev Team"
    Then "Dev Helper" should still be selected

  # Sending Messages
  Scenario: Send a chat message
    Given the chat panel is open
    And agent "Code Helper" is selected
    When I type "How do I write a test?" in the message input
    And I click the Send button
    Then my message should appear in the chat
    And the message should have role "user"
    And the message should be saved to the database

  Scenario: Send message with Enter key
    Given the chat panel is open
    When I type "What is TDD?" in the message input
    And I press Enter
    Then the message should be sent
    And the input field should be cleared

  Scenario: Shift+Enter creates new line without sending
    Given the chat panel is open
    When I type "Line 1" in the message input
    And I press Shift+Enter
    And I type "Line 2"
    Then the input should contain both lines
    And the message should not be sent yet

  Scenario: Cannot send empty message
    Given the chat panel is open
    When the message input is empty
    Then the Send button should be disabled
    When I press Enter
    Then no message should be sent

  Scenario: Cannot send message while streaming
    Given the chat panel is open
    And an agent response is currently streaming
    Then the message input should be disabled
    And the Send button should show "Sending..."
    And I cannot submit a new message

  # Receiving Responses
  Scenario: Receive streaming agent response
    Given the chat panel is open
    And I send a message "Explain Clean Architecture"
    Then I should see a loading indicator "Thinking..."
    And the agent response should stream in word by word
    And the streaming content should be displayed in real-time
    When the response completes
    Then the full message should appear in the chat
    And the message should have role "assistant"
    And the message should be saved to the database

  Scenario: Display document source attribution
    Given I am viewing a document titled "Project Specs"
    And the document has URL "/app/workspaces/dev/documents/specs"
    And I send a message in the chat panel
    When the agent responds with context from the document
    Then I should see "Source: Project Specs" below the response
    And the source should be a clickable link to "/app/workspaces/dev/documents/specs"

  Scenario: Cancel streaming response
    Given the chat panel is open
    And I send a message "Write a long essay"
    And the agent starts streaming a response
    When I click the Cancel button
    Then the streaming should stop
    And the partial response should be preserved
    And the message should show "_(Response cancelled)_"
    And I can send a new message

  Scenario: Handle chat error gracefully
    Given the chat panel is open
    And I send a message "Test message"
    When the LLM service returns an error
    Then I should see an error flash message "Chat error: <reason>"
    And the streaming indicator should be removed
    And I can try sending another message

  # Message Management
  Scenario: View message history in chat
    Given I have a chat session with messages:
      | Role      | Content                     |
      | user      | What is Clean Architecture? |
      | assistant | Clean Architecture is...    |
      | user      | Can you give an example?    |
      | assistant | Here's an example...        |
    When I open the chat panel
    Then I should see all 4 messages in order
    And each message should show its timestamp

  Scenario: Delete a message
    Given I have messages in the current chat session
    When I hover over a message
    And I click the delete icon
    And I confirm deletion
    Then the message should be removed from the chat
    And the message should be deleted from the database

  Scenario: Cannot delete another user's message
    Given "Alice" sent a message in a shared context
    When I attempt to delete Alice's message
    Then I should see an error "Message not found"
    And the message should remain in the chat

  Scenario: Insert message content into note
    Given I am viewing a document with an attached note
    And I have an assistant message with content "Here's the solution..."
    When I click the "Insert into note" button on the message
    Then the message content should be inserted at the cursor in the note editor
    And the note should be updated

  Scenario: Insert button only shows on document pages
    Given I am on the dashboard page
    And I have messages in the chat panel
    Then message insert buttons should not be visible
    When I navigate to a document with a note
    Then message insert buttons should become visible

  # Session Management
  Scenario: Create new chat session on first message
    Given I have no active chat session
    When I send my first message "Hello"
    Then a new chat session should be created
    And the session should be associated with my user ID
    And the session should be scoped to the current workspace
    And the session should be scoped to the current project (if any)
    And the message should be saved to the new session

  Scenario: Messages added to existing session
    Given I have an active chat session
    When I send additional messages
    Then all messages should be added to the same session
    And the session updated_at timestamp should be updated

  Scenario: Start new conversation
    Given I have an active chat session with messages
    When I click the "New" button
    Then the chat should be cleared
    And the current session ID should be reset to nil
    And the next message will create a new session

  Scenario: View conversation history
    Given I have multiple chat sessions:
      | Title                    | Messages | Last Updated |
      | Clean Architecture Help  | 8        | 2 hours ago  |
      | TDD Questions            | 5        | 1 day ago    |
      | Feature Planning         | 12       | 3 days ago   |
    When I click the "History" button
    Then I should see the conversations view
    And I should see all 3 conversations
    And each should show title, message count, and time

  Scenario: Load conversation from history
    Given I am in the conversations view
    And there is a conversation titled "TDD Questions"
    When I click on "TDD Questions"
    Then the conversation should load in the chat view
    And all messages from that conversation should be displayed
    And the session should be marked as current
    And I can continue the conversation

  Scenario: Delete conversation from history
    Given I am in the conversations view
    And there is a conversation titled "Old Chat"
    When I click the delete icon on "Old Chat"
    And I confirm deletion
    Then "Old Chat" should be removed from the list
    And if it was the active conversation, the chat should be cleared

  Scenario: Empty conversations list shows helpful message
    Given I have no saved conversations
    When I view the conversation history
    Then I should see "No conversations yet"
    And I should see a "Start chatting" button
    When I click "Start chatting"
    Then I should return to the chat view

  Scenario: Session title generated from first message
    Given I create a new chat session
    When I send the first message "How do I implement TDD?"
    Then the session title should be generated from the message
    And the title should be truncated to 255 characters if needed

  Scenario: Restore most recent session on mount
    Given I have multiple chat sessions
    And my most recent session is "Current Work"
    When I reload the page
    And I open the chat panel
    Then the "Current Work" session should be automatically restored
    And all messages should be displayed

  # Context Integration
  Scenario: Chat uses document context when available
    Given I am viewing a document with content "# Architecture\n\nOur system uses Clean Architecture"
    And agent "Helper" is selected
    When I send a message "What architecture do we use?"
    Then the system message should include the document content
    And the agent should be able to reference the document in its response

  Scenario: Agent system prompt combined with document context
    Given I am viewing a document with content "Product requirements..."
    And agent "Analyzer" has system prompt "You are an expert analyst"
    When I send a message "What are the requirements?"
    Then the system message should include "You are an expert analyst"
    And the system message should include the document content
    And both should be available to the LLM

  Scenario: Chat without document context
    Given I am on the dashboard (no document open)
    And agent "General Helper" is selected
    When I send a message "What is Clean Architecture?"
    Then only the agent's system prompt should be included
    And no document context should be sent to the LLM

  Scenario: Agent configuration affects LLM call
    Given agent "Precise Bot" has:
      | Model       | gpt-4o  |
      | Temperature | 0.1     |
    And I have selected "Precise Bot"
    When I send a message
    Then the LLM should be called with model "gpt-4o"
    And the LLM should be called with temperature 0.1

  # Real-time Updates
  Scenario: Receive streaming chunks via Phoenix LiveView
    Given the chat panel is open
    And I send a message
    When the LLM service sends chunk "Hello"
    Then the chat panel should receive {:chunk, "Hello"} message
    And the chunk should be appended to the stream buffer
    And the display should update in real-time

  Scenario: Streaming completion via Phoenix LiveView
    Given the chat panel is streaming a response
    When the LLM service sends {:done, "Full response text"}
    Then the chat panel should receive the done message
    And the full response should be saved as an assistant message
    And the stream buffer should be cleared
    And streaming state should be set to false

  Scenario: Handle streaming error
    Given the chat panel is streaming a response
    When the LLM service sends {:error, "API timeout"}
    Then the streaming should stop
    And I should see error flash "Chat error: API timeout"
    And the stream buffer should be cleared

  Scenario: Chat panel updates when agents change
    Given I am viewing workspace "Dev Team"
    And the chat panel is open with agents list
    When another user creates a new agent in the workspace
    Then the chat panel should receive a PubSub notification
    And the agents list should refresh
    And the new agent should appear in the selector

  Scenario: Chat panel updates when agent is deleted
    Given agent "Helper Bot" is selected in the chat panel
    When the agent "Helper Bot" is deleted
    Then the chat panel should receive a PubSub notification
    And "Helper Bot" should be removed from the selector
    And if it was selected, another agent should be auto-selected

  Scenario: Agent selection broadcast to parent LiveView
    Given I am on a page with JavaScript hooks
    When I select agent "Code Helper" in the chat panel
    Then an "agent-selected" event should be broadcast
    And the event should include the agent ID
    And parent LiveView should receive the event

  # UI States and Validation
  Scenario: Clear chat removes all messages
    Given I have messages in the chat
    When I click the "Clear" button
    Then all messages should be removed from view
    And the stream buffer should be cleared
    But the messages should still exist in the database session

  Scenario: Clear button disabled when chat is empty
    Given I have no messages in the chat
    Then the "Clear" button should be disabled

  Scenario: New conversation button disabled when chat is empty
    Given I have no messages in the chat
    Then the "New" button should be disabled

  Scenario: Auto-scroll to bottom on new messages
    Given I have many messages in the chat
    And the chat is scrolled to the top
    When a new assistant message arrives
    Then the chat should auto-scroll to show the newest message

  Scenario: Chat panel maintains collapsed state
    Given the chat panel is open
    When I close the panel
    And I navigate to another page
    Then the panel should remain closed
    And opening it again should restore the previous state

  # Message Formatting
  Scenario: User messages display correctly
    Given I send a message "This is my question"
    Then the message should display with a user icon
    And the message should be left-aligned
    And the timestamp should be shown

  Scenario: Assistant messages display correctly
    Given I receive an assistant response "This is the answer"
    Then the message should display with an assistant icon
    And the message should be right-aligned
    And the timestamp should be shown
    And markdown formatting should be rendered

  Scenario: Long messages are scrollable
    Given I receive a very long assistant response
    Then the message content should be fully visible
    And the chat container should scroll vertically

  Scenario: Code blocks in messages are syntax highlighted
    Given I receive an assistant message with code:
      """
      ```elixir
      def hello do
        IO.puts("Hello, World!")
      end
      ```
      """
    Then the code should be displayed in a code block
    And the code should have syntax highlighting for Elixir

  # Session Restoration
  Scenario: Restore session from localStorage
    Given I have session ID "abc-123" saved in localStorage
    When the chat panel mounts
    And the session exists in the database
    And I own the session
    Then the session should be loaded
    And all messages should be displayed

  Scenario: Clear invalid session from localStorage
    Given I have session ID "invalid-xyz" saved in localStorage
    When the chat panel mounts
    And the session does not exist in the database
    Then a clear_session event should be pushed to the client
    And the localStorage should be cleared

  Scenario: Cannot restore another user's session
    Given I have session ID "abc-123" saved in localStorage
    And the session belongs to another user
    When the chat panel mounts
    Then the session should not be loaded
    And the chat should start empty

  # Keyboard Shortcuts and Accessibility
  Scenario: Focus message input when panel opens
    Given the chat panel is closed
    When I open the chat panel
    Then the message input should receive focus
    And I can start typing immediately

  Scenario: Chat panel is keyboard navigable
    Given the chat panel is open
    When I press Tab
    Then focus should move through interactive elements in order:
      | Element          |
      | New button       |
      | History button   |
      | Close button     |
      | Agent selector   |
      | Message input    |
      | Send button      |

  Scenario: Escape key closes chat panel
    Given the chat panel is open
    When I press Escape
    Then the chat panel should close

  Scenario: ARIA labels for accessibility
    Given the chat panel is rendered
    Then the toggle button should have aria-label "Open chat"
    And the close button should have aria-label "Close chat"
    And the agent selector should have a descriptive label
    And screen readers can navigate the chat history

  # Edge Cases
  Scenario: Handle rapid message sending
    Given the chat panel is open
    When I send 5 messages in quick succession
    Then each message should be saved to the database
    And each should receive a separate agent response
    And the responses should stream in order

  Scenario: Handle concurrent sessions in different tabs
    Given I have the chat panel open in two browser tabs
    When I send a message in tab 1
    Then tab 2 should also see the new message
    And both tabs should show the same conversation

  Scenario: Preserve chat across LiveView reconnections
    Given I have an active chat session with messages
    When the LiveView connection is lost
    And the connection is restored
    Then my chat session should be restored
    And all messages should still be visible

  Scenario: Handle empty workspace agents list
    Given I am in a workspace with no enabled agents
    When I open the chat panel
    Then the agent selector should be empty or hidden
    And I should see a helpful message about adding agents

  Scenario: Handle deleted agent in session
    Given I had agent "Bot X" selected
    And I start a conversation with "Bot X"
    When "Bot X" is deleted mid-conversation
    Then I can still view the existing messages
    And the agent selector should show remaining agents
    And I should be prompted to select a different agent

  # Message Timestamps
  Scenario: Display relative timestamps
    Given I have messages sent at different times:
      | Sent          | Expected Display |
      | 30 seconds ago| just now        |
      | 5 minutes ago | 5m ago          |
      | 2 hours ago   | 2h ago          |
      | 1 day ago     | 1d ago          |
      | 5 days ago    | 5d ago          |
      | 2 weeks ago   | 2w ago          |
    When I view the chat
    Then each message should show its relative timestamp correctly

  # Integration with Document Editor
  Scenario: Chat panel available in document editor
    Given I am editing a document
    When I open the chat panel
    Then the panel should overlay the document editor
    And I can continue editing while chatting
    And the editor should remain functional

  Scenario: Insert chat response into document note
    Given I am editing a document with a note
    And I receive an agent response "Use dependency injection"
    When I click "Insert into note" on the response
    Then "Use dependency injection" should be inserted at my cursor position
    And I can continue editing the note

  Scenario: Context switches when changing documents
    Given I am viewing "Document A" with chat panel open
    When I navigate to "Document B"
    Then the chat panel should use "Document B" as context
    And future messages should reference "Document B"
    But my conversation history should persist

  # Performance and Optimization
  Scenario: Limit conversation history to 20 sessions
    Given I have created 25 chat sessions
    When I view the conversation history
    Then I should see only the 20 most recent sessions
    And older sessions should not be displayed

  Scenario: Chat panel renders efficiently with many messages
    Given I have a session with 100 messages
    When I load the session
    Then all messages should render without lag
    And scrolling should be smooth

  Scenario: Streaming updates don't block UI
    Given an agent is streaming a long response
    When I try to interact with other UI elements
    Then the interface should remain responsive
    And I can navigate away if needed
