@browser @chat @panel
Feature: Chat Panel Core
  As a user
  I want to open and close the global chat panel
  So that I can access AI assistance when needed without cluttering my workspace

  # Chat is a global drawer panel on the right side of every authenticated page.
  # There is no separate /chat route. The panel is toggled via a checkbox input.

  Background:
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    Then the URL should contain "/app"

  Scenario: Chat panel toggle exists on authenticated pages
    Then "label[for='chat-drawer-global-chat-panel']" should exist

  Scenario: Open chat panel displays chat interface
    When I click "label[for='chat-drawer-global-chat-panel'][aria-label='Open chat']"
    And I wait for "div#chat-panel-content" to be visible
    Then "div#chat-panel-content" should be visible
    And "div#chat-messages" should exist
    And "textarea#chat-input" should exist

  Scenario: Toggle chat panel open and closed
    When I click "label[for='chat-drawer-global-chat-panel'][aria-label='Open chat']"
    And I wait for "div#chat-panel-content" to be visible
    Then "div#chat-panel-content" should be visible
    When I click "label[for='chat-drawer-global-chat-panel'][aria-label='Close chat']"
    And I wait for "div#chat-panel-content" to be hidden
    Then "div#chat-panel-content" should be hidden

  Scenario: Chat panel shows empty state before any messages
    When I click "label[for='chat-drawer-global-chat-panel'][aria-label='Open chat']"
    And I wait for "div#chat-panel-content" to be visible
    Then I should see "Ask me anything about this document"

  Scenario: Chat panel available on workspace page
    Given I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    When I wait for the page to load
    Then "label[for='chat-drawer-global-chat-panel']" should exist

  Scenario: New conversation button disabled when chat is empty
    When I click "label[for='chat-drawer-global-chat-panel'][aria-label='Open chat']"
    And I wait for "div#chat-panel-content" to be visible
    Then "button[phx-click='new_conversation']" should be disabled

  Scenario: Chat header shows history and new conversation buttons
    When I click "label[for='chat-drawer-global-chat-panel'][aria-label='Open chat']"
    And I wait for "div#chat-panel-content" to be visible
    Then "button[phx-click='new_conversation']" should exist
    And "button[phx-click='show_conversations']" should exist
