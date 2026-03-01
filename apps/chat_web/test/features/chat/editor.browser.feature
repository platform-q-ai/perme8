@browser @chat @editor
Feature: Chat Editor Integration
  As a user
  I want to use the chat panel while working in the document editor
  So that I can get AI assistance without leaving my editing context

  # Chat is a global drawer panel that coexists with the document editor.
  # There is no separate editor chat -- the same global chat panel is used.
  # All scenarios open the chat drawer on a workspace page.

  Background:
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    Given I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle

  Scenario: Chat panel accessible from workspace page
    When I click ".drawer-content > .navbar label[for='chat-drawer-global-chat-panel']"
    And I wait for "div#chat-panel-content" to be visible
    Then "div#chat-panel-content" should be visible
    And "textarea#chat-input" should be visible
    And "div#chat-messages" should exist

  Scenario: Can send message from chat panel on workspace page
    When I click ".drawer-content > .navbar label[for='chat-drawer-global-chat-panel']"
    And I wait for "div#chat-panel-content" to be visible
    And I fill "textarea#chat-input" with "How do I write a test?"
    And I click the "Send" button
    And I wait for "div.chat.chat-end" to be visible
    Then I should see "How do I write a test?"

  Scenario: Chat panel can be closed while on workspace page
    When I click ".drawer-content > .navbar label[for='chat-drawer-global-chat-panel']"
    And I wait for "div#chat-panel-content" to be visible
    Then "div#chat-panel-content" should be visible
    When I click "#chat-panel-content label[aria-label='Close chat']"
    And I wait for "div#chat-panel-content" to be hidden
    Then "div#chat-panel-content" should be hidden

  Scenario: Agent selector available in chat panel on workspace page
    When I click ".drawer-content > .navbar label[for='chat-drawer-global-chat-panel']"
    And I wait for "div#chat-panel-content" to be visible
    Then "select#agent-selector" should be visible

  @wip
  Scenario: Chat response appears while on workspace page
    When I click ".drawer-content > .navbar label[for='chat-drawer-global-chat-panel']"
    And I wait for "div#chat-panel-content" to be visible
    And I select "${agentName}" from "select#agent-selector"
    And I fill "textarea#chat-input" with "What is a PRD?"
    And I click the "Send" button
    And I wait for "div.chat.chat-start" to be visible
    Then "div.chat.chat-start" should be visible

  Scenario: Chat message form has correct structure
    When I click ".drawer-content > .navbar label[for='chat-drawer-global-chat-panel']"
    And I wait for "div#chat-panel-content" to be visible
    Then "#chat-message-form" should exist
    And "#chat-message-form[phx-submit='send_message']" should exist
    And "textarea#chat-input[name='message']" should exist
