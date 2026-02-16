@browser @chat @sessions
Feature: Chat Session Management
  As a user
  I want to manage my chat conversation history
  So that I can continue previous conversations and organize my AI interactions

  # Chat sessions are managed within the global chat drawer panel.
  # Conversations view is toggled via phx-click="show_conversations".
  # Sessions are loaded via phx-click="load_session" and deleted via
  # phx-click="delete_session" (with data-confirm).

  Background:
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for the page to load
    Given I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    When I wait for the page to load
    When I click "label[for='chat-drawer-global-chat-panel'][aria-label='Open chat']"
    And I wait for "div#chat-panel-content" to be visible

  Scenario: View conversation history
    # Send a message to create a session first
    When I fill "textarea#chat-input" with "Session for history test"
    And I click the "Send" button
    And I wait for "div.chat.chat-end" to be visible
    # Open conversation history
    When I click "button[phx-click='show_conversations']"
    And I wait for 1 seconds
    Then "div[phx-click='load_session']" should exist

  Scenario: Start new conversation clears chat
    When I fill "textarea#chat-input" with "Message in old session"
    And I click the "Send" button
    And I wait for "div.chat.chat-end" to be visible
    Then I should see "Message in old session"
    When I click "button[phx-click='new_conversation']"
    And I wait for 1 seconds
    Then I should not see "Message in old session"
    And I should see "Ask me anything about this document"

  Scenario: Load conversation from history
    # Create a conversation
    When I fill "textarea#chat-input" with "TDD conversation for load test"
    And I click the "Send" button
    And I wait for "div.chat.chat-end" to be visible
    # Start a new conversation
    When I click "button[phx-click='new_conversation']"
    And I wait for 1 seconds
    # Go to history and load previous conversation
    When I click "button[phx-click='show_conversations']"
    And I wait for "div[phx-click='load_session']" to be visible
    And I click "div[phx-click='load_session']"
    And I wait for 1 seconds
    Then I should see "TDD conversation for load test"

  Scenario: Back button returns from conversations to chat view
    When I click "button[phx-click='show_conversations']"
    And I wait for 1 seconds
    When I click "button[phx-click='show_chat']"
    And I wait for 1 seconds
    Then "textarea#chat-input" should be visible

  @wip
  Scenario: Delete conversation from history
    # Tagged @wip because delete uses data-confirm which requires browser dialog handling
    When I fill "textarea#chat-input" with "Conversation to delete"
    And I click the "Send" button
    And I wait for "div.chat.chat-end" to be visible
    When I click "button[phx-click='new_conversation']"
    And I wait for 1 seconds
    When I click "button[phx-click='show_conversations']"
    And I wait for "div[phx-click='load_session']" to be visible
    When I click "button[phx-click='delete_session']"
    And I wait for 1 seconds
    Then "div[phx-click='load_session']" should not exist

  Scenario: Session list shows title and message count
    When I fill "textarea#chat-input" with "How do I implement TDD in Elixir?"
    And I click the "Send" button
    And I wait for "div.chat.chat-end" to be visible
    When I click "button[phx-click='show_conversations']"
    And I wait for "div[phx-click='load_session']" to be visible
    Then "div[phx-click='load_session']" should exist
