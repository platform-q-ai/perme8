@browser @chat @messaging
Feature: Chat Messaging
  As a user
  I want to send messages to AI agents and receive responses
  So that I can get help with my work

  # Chat is a global drawer panel. Messages are sent via a form with
  # phx-submit="send_message". User messages appear as div.chat.chat-end,
  # assistant messages as div.chat.chat-start.

  Background:
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for the page to load
    # Navigate to a workspace so agents are available
    Given I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    When I wait for the page to load
    # Open the chat panel
    When I click "label[for='chat-drawer-global-chat-panel'][aria-label='Open chat']"
    And I wait for "div#chat-panel-content" to be visible

  Scenario: Send a message and see it displayed
    When I fill "textarea#chat-input" with "How do I write a test?"
    And I click the "Send" button
    And I wait for "div.chat.chat-end" to be visible
    Then I should see "How do I write a test?"

  Scenario: Send button disabled when input is empty
    When I clear "textarea#chat-input"
    Then "#chat-message-form button[type='submit']" should be disabled

  Scenario: User message appears with correct styling
    When I fill "textarea#chat-input" with "Hello from the test"
    And I click the "Send" button
    And I wait for "div.chat.chat-end" to be visible
    Then "div.chat.chat-end" should be visible

  @wip
  Scenario: Receive agent response after sending message
    When I fill "textarea#chat-input" with "What is TDD?"
    And I click the "Send" button
    And I wait for "div.chat.chat-start" to be visible
    Then "div.chat.chat-start" should be visible

  Scenario: Clear button resets chat
    When I fill "textarea#chat-input" with "Message before clear"
    And I click the "Send" button
    And I wait for "div.chat.chat-end" to be visible
    Then I should see "Message before clear"
    When I click the "Clear" button
    And I wait for 1 seconds
    Then I should not see "Message before clear"

  @wip
  Scenario: Delete a user message
    When I fill "textarea#chat-input" with "Message to delete"
    And I click the "Send" button
    And I wait for "div.chat.chat-end" to be visible
    Then I should see "Message to delete"
    When I click "span[phx-click='delete_message']"
    And I wait for 1 seconds
    Then I should not see "Message to delete"

  Scenario: Chat input has correct placeholder text
    Then "textarea#chat-input" should exist
    And "textarea#chat-input[placeholder='Ask about this document...']" should exist

  Scenario: Chat input has correct attributes
    Then "textarea#chat-input[name='message']" should exist
    And "textarea#chat-input[rows='3']" should exist
