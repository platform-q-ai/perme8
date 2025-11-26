Feature: Chat Panel
  As a user
  I want to interact with AI agents through a global chat panel
  So that I can get help and insights while working on documents and projects

  Background:
    Given I am logged in as a user
    And I have at least one enabled agent available

  # Panel Display and Interaction
  @javascript
  Scenario: Chat panel closed by default on mobile
    Given I am on any page with the admin layout for browser tests
    And I am viewing on a mobile viewport under 1024 px
    And I have not previously interacted with the chat panel for browser tests
    When the page loads for browser tests
    Then the chat panel should be closed by default
    And the chat toggle button should be visible

  @javascript
  Scenario: Toggle chat panel open and closed
    Given the chat panel is closed
    When I click the chat toggle button
    Then the chat panel should slide open from the right
    And the panel should display the chat interface
    And the toggle button should be hidden
    And my preference should be saved to localStorage
    When I click the close button
    Then the chat panel should slide closed
    And the toggle button should become visible
    And my preference should be saved to localStorage

  @javascript
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

  @javascript
  @javascript
  Scenario: Chat panel is resizable
    Given the chat panel is open
    And the panel has default width of 384 px
    When I drag the resize handle to the left
    Then the panel width should increase
    When I drag the resize handle to the right
    Then the panel width should decrease
    And the resized width should be saved to localStorage

  @javascript
  Scenario: Resized chat panel persists across page navigation
    Given the chat panel is open
    And I resize the panel to 500 px width
    When I navigate to another page
    Then the chat panel should maintain 500 px width
    And the width should be restored from localStorage

  @javascript
  Scenario: Resized chat panel maintains width during agent response
    Given the chat panel is open
    And I resize the panel to 600 px width
    When I send a message to the agent
    And the agent starts streaming a response
    Then the panel width should remain 600 px
    When the response completes
    Then the panel width should still be 600 px
    And the panel should not resize or shift

  @javascript
  Scenario: Empty chat shows welcome message
    Given I am on desktop for browser tests (panel open by default)
    And I have no messages in the current session
    Then I should see the welcome icon (chat bubble)
    And I should see "Ask me anything about this document"

  # Agent Selection
  @javascript
  Scenario: Select agent from dropdown
    Given the chat panel is open
    And workspace has agents "Code Helper" and "Doc Writer"
    When I open the agent selector dropdown
    Then I should see "Code Helper" in the list
    And I should see "Doc Writer" in the list
    When I select "Doc Writer"
    Then "Doc Writer" should be marked as selected
    And my selection should be saved to preferences

  @javascript
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

  @javascript
  Scenario: Auto-select first agent when none selected
    Given I am in workspace "Dev Team"
    And I have no previously selected agent for this workspace
    And workspace has agents "Alpha Bot" and "Beta Bot"
    When I open the chat panel
    Then "Alpha Bot" should be automatically selected

  @javascript
  Scenario: Restore previously selected agent
    Given I am in workspace "Dev Team"
    And I previously selected agent "Code Helper"
    When I open the chat panel
    Then "Code Helper" should be selected
    And I can start chatting immediately

  @javascript
  Scenario: Agent selection persists across workspace visits
    Given I am in workspace "Dev Team"
    When I select agent "Dev Helper" in the chat panel
    And I navigate to workspace "QA Team"
    And I select agent "QA Bot" in the chat panel
    And I navigate back to workspace "Dev Team"
    Then "Dev Helper" should still be selected

  # Sending Messages
  @javascript
  Scenario: Send a chat message
    Given the chat panel is open
    And agent "Code Helper" is selected
    When I type "How do I write a test?" in the message input
    And I click the Send button
    Then my message should appear in the chat
    And the message should have role "user"
    And the message should be saved to the database

  @javascript
  Scenario: Send message with Enter key
    Given the chat panel is open
    When I type "What is TDD?" in the message input
    And I press Enter
    Then the message should be sent
    And the input field should be cleared

  @javascript
  Scenario: Shift+Enter creates new line without sending
    Given the chat panel is open
    When I type "Line 1" in the message input
    And I press Shift+Enter
    And I type "Line 2"
    Then the input should contain both lines
    And the message should not be sent yet

  @javascript
  Scenario: Cannot send empty message
    Given the chat panel is open
    When the message input is empty
    Then the Send button should be disabled
    When I press Enter
    Then no message should be sent

  @javascript
  Scenario: Cannot send message while streaming
    Given the chat panel is open
    And an agent response is currently streaming
    Then the message input should be disabled
    And the Send button should show "Sending..."
    And I cannot submit a new message

  # Receiving Responses
  @javascript
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

  @javascript
  Scenario: Display document source attribution
    Given I am viewing a document titled "Project Specs"
    And the document has URL "/app/workspaces/dev/documents/specs"
    And I send a message in the chat panel
    When the agent responds with context from the document
    Then I should see "Source: Project Specs" below the response
    And the source should be a clickable link to "/app/workspaces/dev/documents/specs"

  @javascript
  Scenario: Cancel streaming response
    Given the chat panel is open
    And I send a message "Write a long essay"
    And the agent starts streaming a response
    When I click the Cancel button
    Then the streaming should stop
    And the partial response should be preserved
    And the message should show a cancelled indicator
    And I can send a new message

  @javascript
  Scenario: Handle chat error gracefully
    Given the chat panel is open
    And I send a message "Test message"
    When the LLM service returns an error
    Then I should see an error flash message containing "Chat error"
    And the streaming indicator should be removed
    And I can try sending another message

  # Message Management
  @javascript
  Scenario: View message history in chat
    Given I have a chat session with messages:
      | Role      | Content                     |
      | user      | What is Clean Architecture  |
      | assistant | Clean Architecture is...    |
      | user      | Can you give an example     |
      | assistant | Here's an example...        |
    When I open the chat panel
    Then I should see all 4 messages in order
    And each message should show its timestamp

  @javascript
  Scenario: Delete a message
    Given I have messages in the current chat session
    When I hover over a message
    And I click the delete icon
    And I confirm deletion
    Then the message should be removed from the chat
    And the message should be deleted from the database

  @javascript
  Scenario: Delete link appears in message footer for saved messages
    Given I have a chat session with saved messages
    When I view the messages in the chat panel
    Then each message with an ID should show a "delete" link in the footer
    And the delete link should be styled as a clickable link in red (text-error)
    And the delete link should have aria attributes for accessibility

  @javascript
  Scenario: Delete link does not appear for streaming messages
    Given I am receiving a streaming agent response
    Then the streaming message should not show a delete link
    And the message footer should be hidden during streaming
    When the response completes
    Then the delete link should appear in the message footer

  @javascript
  Scenario: Delete link does not appear for unsaved messages
    Given I have a message that hasn't been saved to the database yet
    When I view the message in the chat panel
    Then the message should not show a delete link
    And the message footer should only show other available actions

  @javascript
  Scenario: Delete message shows confirmation dialog
    Given I have a saved message in the chat
    When I click the "delete" link
    Then I should see a confirmation dialog "Delete this message?"
    When I confirm
    Then the message should be deleted
    When I cancel
    Then the message should remain in the chat

  @javascript
  Scenario: Cannot delete message from non-existent session
    Given I have a message ID from a deleted or non-existent session
    When I attempt to delete the message
    Then I should see an error "Message not found"

  @javascript
  Scenario: Insert message content into note
    Given I am viewing a document with an attached note
    And I have an assistant message with content "Here's the solution..."
    When I click the "Insert into note" button on the message
    Then the message content should be inserted at the cursor in the note editor
    And the note should be updated

  @javascript
  Scenario: Insert button only shows on document pages
    Given I am on the dashboard page
    And I have messages in the chat panel
    Then message insert buttons should not be visible
    When I navigate to a document with a note
    Then message insert buttons should become visible

  # Session Management
  @javascript
  Scenario: Create new chat session on first message
    Given I have no active chat session
    When I send my first message "Hello"
    Then a new chat session should be created
    And the session should be associated with my user ID
    And the session should be scoped to the current workspace
    And the session should be scoped to the current project if available
    And the message should be saved to the new session

  @javascript
  Scenario: Messages added to existing session
    Given I have an active chat session
    When I send additional messages
    Then all messages should be added to the same session
    And the session updated_at timestamp should be updated

  @javascript
  Scenario: Start new conversation
    Given I have an active chat session with messages
    When I click the "New" button
    Then the chat should be cleared
    And the current session ID should be reset to nil
    And the next message will create a new session

  @javascript
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

  @javascript
  Scenario: Load conversation from history
    Given I am in the conversations view
    And there is a conversation titled "TDD Questions"
    When I click on "TDD Questions"
    Then the conversation should load in the chat view
    And all messages from that conversation should be displayed
    And the session should be marked as current
    And I can continue the conversation

  @javascript
  Scenario: Delete conversation from history
    Given I am in the conversations view
    And there is a conversation titled "Old Chat"
    When I click the delete icon on "Old Chat"
    And I confirm deletion
    Then "Old Chat" should be removed from the list
    And if it was the active conversation, the chat should be cleared

  @javascript
  Scenario: Delete icon visible on all conversations in history
    Given I am in the conversations view
    And I have 5 saved conversations
    Then each conversation should display a trash icon button
    And the icon should be positioned on the right side
    And the icon should be a small circular ghost button
    And hovering over the icon should show visual feedback

  @javascript
  Scenario: Delete conversation shows confirmation dialog
    Given I am in the conversations view
    And there is a conversation "Important Chat"
    When I click the trash icon
    Then I should see a confirmation dialog "Delete this conversation?"
    When I confirm
    Then the conversation should be deleted from the database
    And it should be removed from the list
    When I cancel the deletion
    Then the conversation should remain in the list

  @javascript
  Scenario: Deleting active conversation clears chat view
    Given I am viewing conversation "Current Work"
    And the chat panel shows messages from "Current Work"
    When I switch to conversations view
    And I delete "Current Work"
    Then "Current Work" should be removed from the list
    And when I return to chat view, the chat should be empty
    And the current_session_id should be nil

  @javascript
  Scenario: Deleting inactive conversation preserves active chat
    Given I am viewing conversation "Session A"
    And the chat panel shows messages from "Session A"
    When I switch to conversations view
    And I delete a different conversation "Session B"
    Then "Session B" should be removed from the list
    When I return to chat view
    Then "Session A" messages should still be visible
    And the current session should still be "Session A"

  @javascript
  Scenario: Empty conversations list shows helpful message
    Given I have no saved conversations
    When I view the conversation history
    Then I should see "No conversations yet"
    And I should see a "Start chatting" button
    When I click "Start chatting"
    Then I should return to the chat view

  @javascript
  Scenario: Session title generated from first message
    Given I create a new chat session
    When I send the first message "How do I implement TDD?"
    Then the session title should be generated from the message
    And the title should be truncated to 255 characters if needed

  @javascript
  Scenario: Restore most recent session on mount
    Given I have multiple chat sessions
    And my most recent session is "Current Work"
    When I reload the page
    And I open the chat panel
    Then the "Current Work" session should be automatically restored
    And all messages should be displayed

  # Context Integration
  @javascript
  Scenario: Chat uses document context when available
    Given I am viewing a document with content "# Architecture\n\nOur system uses Clean Architecture"
    And agent "Helper" is selected
    When I send a message "What architecture do we use?"
    Then the system message should include the document content
    And the agent should be able to reference the document in its response

  @javascript
  Scenario: Agent system prompt combined with document context
    Given I am viewing a document with content "Product requirements..."
    And agent "Analyzer" has system prompt "You are an expert analyst"
    When I send a message "What are the requirements?"
    Then the system message should include "You are an expert analyst"
    And the system message should include the document content
    And both should be available to the LLM

  @javascript
  Scenario: Chat without document context
    Given I am on the dashboard (no document open)
    And agent "General Helper" is selected
    When I send a message "What is Clean Architecture"
    Then only the agent's system prompt should be included
    And no document context should be sent to the LLM

  @javascript
  Scenario: Agent configuration affects LLM call
    Given agent "Precise Bot" has:
      | Model       | gpt-4o  |
      | Temperature | 0.1     |
    And I have selected "Precise Bot"
    When I send a message
    Then the LLM should be called with model "gpt-4o"
    And the LLM should be called with temperature 0.1

  # Real-time Updates
  @javascript
  Scenario: Receive streaming chunks via Phoenix LiveView
    Given the chat panel is open
    And I send a message
    When the LLM service sends a chunk with content "Hello"
    Then the chat panel should receive the chunk message
    And the chunk should be appended to the stream buffer
    And the display should update in real-time

  @javascript
  Scenario: Streaming completion via Phoenix LiveView
    Given the chat panel is streaming a response
    When the LLM service sends a done message with "Full response text"
    Then the chat panel should receive the done message
    And the full response should be saved as an assistant message
    And the stream buffer should be cleared
    And streaming state should be set to false

  @javascript
  Scenario: Handle streaming error
    Given the chat panel is streaming a response
    When the LLM service sends an error with "API timeout"
    Then the streaming should stop
    And I should see error flash "Chat error: API timeout"
    And the stream buffer should be cleared

  @javascript
  Scenario: Chat panel updates when agents change
    Given I am viewing workspace "Dev Team"
    And the chat panel is open with agents list
    When another user creates a new agent in the workspace
    Then the chat panel should receive a PubSub notification
    And the agents list should refresh
    And the new agent should appear in the selector

  @javascript
  Scenario: Chat panel updates when agent is deleted
    Given agent "Helper Bot" is selected in the chat panel
    When the agent "Helper Bot" is deleted
    Then the chat panel should receive a PubSub notification
    And "Helper Bot" should be removed from the selector
    And if it was selected, another agent should be auto-selected

  @javascript
  Scenario: Agent selection broadcast to parent LiveView
    Given I am on a page with JavaScript hooks
    When I select agent "Code Helper" in the chat panel
    Then an "agent-selected" event should be broadcast
    And the event should include the agent ID
    And parent LiveView should receive the event

  # UI States and Validation
  @javascript
  Scenario: Clear chat removes all messages
    Given I have messages in the chat
    When I click the "Clear" button
    Then all messages should be removed from view
    And the stream buffer should be cleared
    But the messages should still exist in the database session

  @javascript
  Scenario: Clear button disabled when chat is empty
    Given I have no messages in the chat
    Then the "Clear" button should be disabled

  @javascript
  Scenario: New conversation button disabled when chat is empty
    Given I have no messages in the chat
    Then the "New" button should be disabled

  @javascript
  Scenario: Auto-scroll to bottom on new messages
    Given I have many messages in the chat
    And the chat is scrolled to the top
    When a new assistant message arrives
    Then the chat should auto-scroll to show the newest message

  @javascript
  Scenario: Chat panel restores user preference across page loads
    Given I am on desktop for browser tests
    And the chat panel is open by default
    When I close the panel
    And I navigate to another page
    Then the panel should remain closed based on user preference
    When I open the panel again
    And I navigate to another page
    Then the panel should remain open based on user preference

  @javascript
  Scenario: Chat panel auto-adjusts on resize without user interaction
    Given I am on desktop with the panel open by default for browser tests
    And I have not manually toggled the panel
    When I resize the browser to mobile viewport
    Then the panel should automatically close
    When I resize back to desktop viewport
    Then the panel should automatically open

  @javascript
  Scenario: Chat panel preserves user preference during resize
    Given I am on desktop for browser tests
    And I manually close the chat panel
    When I resize to mobile and back to desktop
    Then the panel should remain closed based on user preference
    Given I manually open the chat panel
    When I resize to mobile and back to desktop
    Then the panel should remain open based on user preference

  # Message Formatting
  @javascript
  Scenario: User messages display correctly
    Given I send a message "This is my question"
    Then the message should display with a user icon
    And the message should be left-aligned
    And the timestamp should be shown

  @javascript
  Scenario: Assistant messages display correctly
    Given I receive an assistant response "This is the answer"
    Then the message should display with an assistant icon
    And the message should be right-aligned
    And the timestamp should be shown
    And markdown formatting should be rendered

  @javascript
  Scenario: Long messages are scrollable
    Given I receive a very long assistant response
    Then the message content should be fully visible
    And the chat container should scroll vertically

  @javascript
  Scenario: Code blocks in messages are syntax highlighted
    Given I receive an assistant message with code:
      """
      def hello do
        IO.puts("Hello, World!")
      end
      """
    Then the code should be displayed in a code block
    And the code should have syntax highlighting for Elixir

  @javascript
  Scenario: Markdown headings are rendered in assistant messages
    Given I receive an assistant message with markdown:
      """
      # Main Heading
      ## Subheading
      ### Sub-subheading
      """
    Then I should see the headings rendered as <h1>, <h2>, and <h3> elements
    And I should not see raw markdown syntax (#, ##, ###)

  @javascript
  Scenario: Markdown emphasis is rendered in assistant messages
    Given I receive an assistant message "This is **bold** and this is *italic* text"
    Then "bold" should be rendered in bold (strong tag)
    And "italic" should be rendered in italic (em tag)
    And I should not see asterisks in the rendered message

  @javascript
  Scenario: Markdown lists are rendered in assistant messages
    Given I receive an assistant message with a list:
      """
      Steps to follow:
      1. First step
      2. Second step
      - Bullet point A
      - Bullet point B
      """
    Then I should see an ordered list with 2 items
    And I should see an unordered list with 2 items
    And list items should be properly formatted

  @javascript
  Scenario: Markdown links are rendered as clickable links
    Given I receive an assistant message "Check out OpenAI for more info"
    Then I should see a clickable link with text "OpenAI"
    And the link should point to "https://openai.com"
    And clicking the link should open in a new tab

  @javascript
  Scenario: Markdown blockquotes are rendered with styling
    Given I receive an assistant message with a blockquote:
      """
      > This is a quote
      > from the documentation
      """
    Then the quote should be displayed in a blockquote element
    And the blockquote should have distinctive styling

  @javascript
  Scenario: Mixed markdown elements render correctly
    Given I receive an assistant message with complex markdown:
      """
      ## Solution

      Here's how to fix it:

      1. **Install dependencies**: Run npm install
      2. *Configure* the settings
      3. Test with this code:

      console.log('Hello');

      See docs for details.
      """
    Then all markdown elements should render correctly
    And headings, lists, bold, italic, code blocks, and links should be visible
    And no raw markdown syntax should be visible

  # Session Restoration
  @javascript
  Scenario: Restore session from localStorage
    Given I have session ID "abc-123" saved in localStorage
    When the chat panel mounts
    And the session exists in the database
    And I own the session
    Then the session should be loaded
    And all messages should be displayed

  @javascript
  Scenario: Clear invalid session from localStorage
    Given I have session ID "invalid-xyz" saved in localStorage
    When the chat panel mounts
    And the session does not exist in the database
    Then a clear_session event should be pushed to the client
    And the localStorage should be cleared

  @javascript
  Scenario: Cannot restore another user's session
    Given I have session ID "abc-123" saved in localStorage
    And the session belongs to another user
    When the chat panel mounts
    Then the session should not be loaded
    And the chat should start empty

  # Keyboard Shortcuts and Accessibility
  @javascript
  Scenario: Focus message input when panel opens
    Given the chat panel is closed
    When I click the toggle button to open the panel
    Then the message input should receive focus after 150ms animation
    And I can start typing immediately

  @javascript
  Scenario: Message input receives focus on desktop initial load
    Given I am on desktop for browser tests
    And I have not interacted with the chat panel before
    When the page loads for browser tests with the panel open by default
    Then the message input should receive focus
    And I can start typing immediately

  @javascript
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

  @javascript
  Scenario: Escape key closes chat panel
    Given the chat panel is open
    When I press Escape
    Then the chat panel should close
    And my preference should be saved to localStorage

  @javascript
  Scenario: Keyboard shortcut toggles chat panel
    Given the chat panel is closed
    When I press the toggle keyboard shortcut
    Then the chat panel should open
    And my preference should be saved to localStorage
    When I press the toggle keyboard shortcut again
    Then the chat panel should close
    And my preference should be saved to localStorage

  @javascript
  Scenario: ARIA labels for accessibility
    Given the chat panel is rendered
    Then the toggle button should have aria-label "Open chat"
    And the close button should have aria-label "Close chat"
    And the agent selector should have a descriptive label
    And screen readers can navigate the chat history

  # Edge Cases
  @javascript
  Scenario: Handle rapid message sending
    Given the chat panel is open
    When I send 5 messages in quick succession
    Then each message should be saved to the database
    And each should receive a separate agent response
    And the responses should stream in order

  @javascript
  Scenario: Handle concurrent sessions in different tabs
    Given I have the chat panel open in two browser tabs
    When I send a message in tab 1
    Then tab 2 should also see the new message
    And both tabs should show the same conversation

  @javascript
  Scenario: Preserve chat across LiveView reconnections
    Given I have an active chat session with messages
    When the LiveView connection is lost
    And the connection is restored
    Then my chat session should be restored
    And all messages should still be visible

  @javascript
  Scenario: Handle empty workspace agents list
    Given I am in a workspace with no enabled agents
    When I open the chat panel
    Then the agent selector should be empty or hidden
    And I should see a helpful message about adding agents

  @javascript
  Scenario: Handle deleted agent in session
    Given I had agent "Bot X" selected
    And I start a conversation with "Bot X"
    When "Bot X" is deleted mid-conversation
    Then I can still view the existing messages
    And the agent selector should show remaining agents
    And I should be prompted to select a different agent

  # Message Timestamps
  @javascript
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
  @javascript
  Scenario: Chat panel available in document editor
    Given I am editing a document
    When I open the chat panel
    Then the panel should overlay the document editor
    And I can continue editing while chatting
    And the editor should remain functional

  @javascript
  Scenario: Insert chat response into document note
    Given I am editing a document with a note
    And I receive an agent response "Use dependency injection"
    When I click "Insert into note" on the response
    Then "Use dependency injection" should be inserted at my cursor position
    And I can continue editing the note

  @javascript
  Scenario: Insert markdown content preserves formatting in editor
    Given I am editing a document with a note
    And I receive an agent response with markdown:
      """
      ## Solution
      Use **dependency injection** for better *testability*.
      """
    When I click "Insert into note" on the response
    Then the markdown should be inserted as formatted text in the editor
    And "Solution" should appear as a heading
    And "dependency injection" should be bold
    And "testability" should be italic
    And the note editor should render the markdown formatting

  @javascript
  Scenario: Insert code block into editor preserves syntax
    Given I am editing a document with a note
    And I receive an agent response with a code block:
      """
      def calculate(a, b), do: a + b
      """
    When I click "Insert into note" on the response
    Then the code block should be inserted into the editor
    And the code should be displayed in a code block element
    And the syntax highlighting should be preserved
    And the code should be properly formatted

  @javascript
  Scenario: Insert list into editor renders as list
    Given I am editing a document with a note
    And I receive an agent response with a list:
      """
      Steps:
      1. First step
      2. Second step
      """
    When I click "Insert into note" on the response
    Then the list should be inserted as a formatted list in the editor
    And I should see numbered list items
    And the list should be editable as a native list element

  @javascript
  Scenario: Insert mixed markdown content into editor
    Given I am editing a document with a note
    And I receive an agent response with complex markdown:
      """
      ### Quick Fix

      Apply these changes:
      - Update **config.exs**
      - Run mix deps.get

      See documentation for more info.
      """
    When I click "Insert into note" on the response
    Then all markdown formatting should be preserved in the editor
    And the heading, list, bold text, inline code, and link should render correctly
    And I can edit the inserted content as formatted elements

  @javascript
  Scenario: Context switches when changing documents
    Given I am viewing "Document A" with chat panel open
    When I navigate to "Document B"
    Then the chat panel should use "Document B" as context
    And future messages should reference "Document B"
    But my conversation history should persist

  # Performance and Optimization
  @javascript
  Scenario: Limit conversation history to 20 sessions
    Given I have created 25 chat sessions
    When I view the conversation history
    Then I should see only the 20 most recent sessions
    And older sessions should not be displayed

  @javascript
  Scenario: Chat panel renders efficiently with many messages
    Given I have a session with 100 messages
    When I load the session
    Then all messages should render without lag
    And scrolling should be smooth

  @javascript
  Scenario: Streaming updates don't block UI
    Given an agent is streaming a long response
    When I try to interact with other UI elements
    Then the interface should remain responsive
    And I can navigate away if needed

  # In-Document Agent Queries
  @javascript
  Scenario: Execute agent query from document editor using @j command
    Given I am editing a document in a workspace
    And workspace has an agent named "code-helper"
    When I type "@j code-helper How do I write a test?" in the editor
    And I press Enter
    Then the agent query should be executed
    And the agent response should stream into the document
    And the response should be inserted at the cursor position

  @javascript
  Scenario: Agent query uses document content as context
    Given I am editing a document with content "# Product Requirements\nFeature: User authentication"
    And workspace has an agent named "analyzer"
    When I execute "@j analyzer What features are described?"
    Then the agent should receive the document content as context
    And the response should reference "user authentication"

  @javascript
  Scenario: Agent query with invalid command format
    Given I am editing a document
    When I type "@j" without an agent name or question
    And I press Enter
    Then I should see an error "Invalid command format. Use: @j agent_name Question"
    And no agent query should be executed

  @javascript
  Scenario: Agent query with non-existent agent
    Given I am editing a document in a workspace
    And the workspace has no agent named "fake-agent"
    When I execute "@j fake-agent What is this?"
    Then I should see an error "Agent not found in workspace"
    And no query should be executed

  @javascript
  Scenario: Agent query with disabled agent
    Given I am editing a document in a workspace
    And workspace has a disabled agent named "old-bot"
    When I execute "@j old-bot Help me"
    Then I should see an error "Agent is disabled"
    And no query should be executed

  @javascript
  Scenario: Cancel in-document agent query
    Given I am editing a document
    And I execute "@j analyzer Explain this document in detail"
    And the agent starts streaming a response
    When I trigger the cancel query action
    Then the streaming should stop
    And the partial response should remain in the document
    And the query process should be terminated

  @javascript
  Scenario: Multiple agent queries in same document
    Given I am editing a document
    When I execute "@j helper-1 First question"
    And I wait for the response to complete
    And I execute "@j helper-2 Second question"
    Then both agent responses should be present in the document
    And each response should be from the correct agent
    And the responses should not interfere with each other

  # Agent Response Rendering in Editor
  @javascript
  Scenario: Agent response displays "Agent thinking..." while waiting
    Given I am editing a document
    When I execute "@j analyzer Analyze this document"
    Then I should immediately see "Agent thinking..." in the editor
    And the text should be displayed with opacity-60 style
    And an animated loading dots indicator should be visible
    And the thinking text should appear at the cursor position

  @javascript
  Scenario: Agent thinking indicator has animated dots
    Given I execute an agent query
    When the "Agent thinking..." text appears
    Then I should see animated dots
    And the dots should have a loading-dots CSS class
    And the animation should indicate ongoing processing

  @javascript
  Scenario: Agent response streams character by character
    Given I execute an agent query
    And the agent starts responding
    When the first chunk "Hello" arrives
    Then "Hello" should appear in the editor
    And a blinking cursor should be shown after "Hello"
    When the next chunk " World" arrives
    Then "Hello World" should be visible
    And the blinking cursor should move to the end
    And the cursor should have streaming-cursor CSS class

  @javascript
  Scenario: Agent response node is atomic and non-editable during streaming
    Given an agent is streaming a response "This is a test"
    When I try to click inside the response text
    Then the cursor should not enter the response node
    And the response should behave as a single atomic unit
    And I cannot edit individual characters while streaming
    When the response completes
    Then the content should be converted to editable markdown

  @javascript
  Scenario: Agent response blinking cursor indicates streaming state
    Given an agent is streaming a response
    Then I should see a blinking cursor following the text
    And the cursor should have the streaming-cursor CSS class
    And the cursor should blink to indicate activity
    When the streaming completes
    Then the blinking cursor should disappear
    And the text should become fully editable

  @javascript
  Scenario: Agent response converted to markdown after completion
    Given an agent is streaming markdown content:
      """
      ## Solution
      Use **dependency injection**
      def hello, do: :world
      """
    When the streaming completes
    Then the atomic agent_response node should be replaced
    And the content should be parsed as markdown
    And I should see a rendered heading "Solution"
    And "dependency injection" should be bold
    And the code block should be syntax highlighted
    And all content should be editable character by character

  @javascript
  Scenario: Agent error displayed inline in editor
    Given I execute an agent query
    When the agent returns an error "API timeout"
    Then I should see "[Agent Error: API timeout]" in the editor
    And the error text should be styled with text-error class (red)
    And the error should be inline with other content
    And I can delete the error node and continue editing

  @javascript
  Scenario: Agent response node attributes track state
    Given an agent response node exists
    Then the node should have data-node-id attribute
    And the node should have data-state attribute (streaming|done|error)
    And the node should have data-content attribute with current text
    When streaming, the state should be "streaming"
    When complete, the state should be "done"
    When error occurs, the state should be "error"

  @javascript
  Scenario: Completed agent response becomes regular editable text
    Given an agent has completed a response "Use Clean Architecture"
    And the response has been converted to markdown
    When I click in the middle of "Clean"
    Then my cursor should position between characters
    And I can type to insert new characters
    And I can delete characters with backspace
    And I can select and copy text
    And the content behaves like normal editor text
