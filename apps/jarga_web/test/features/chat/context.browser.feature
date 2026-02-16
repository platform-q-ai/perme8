@browser @chat @context
Feature: Chat Context Integration
  As a user
  I want the chat to use relevant context from my documents
  So that the AI agent can give me more relevant and accurate responses

  # Chat is a global drawer panel available on all /app/* pages.
  # When on a document page, the chat panel can use document context.
  # Internal LLM configuration (model, temperature, system prompt) cannot
  # be verified in browser tests -- only observable UI behaviors are tested.

  Background:
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for the page to load

  Scenario: Chat panel available on workspace page
    Given I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    When I wait for the page to load
    When I click "label[for='chat-drawer-global-chat-panel'][aria-label='Open chat']"
    And I wait for "div#chat-panel-content" to be visible
    Then "div#chat-panel-content" should be visible
    And "textarea#chat-input" should be visible

  Scenario: Chat panel shows empty state prompt
    Given I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    When I wait for the page to load
    When I click "label[for='chat-drawer-global-chat-panel'][aria-label='Open chat']"
    And I wait for "div#chat-panel-content" to be visible
    Then I should see "Ask me anything about this document"

  @wip
  Scenario: Send message with document context and receive response
    Given I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    When I wait for the page to load
    When I click "label[for='chat-drawer-global-chat-panel'][aria-label='Open chat']"
    And I wait for "div#chat-panel-content" to be visible
    And I select "${agentName}" from "select#agent-selector"
    And I fill "textarea#chat-input" with "Summarize this document"
    And I click the "Send" button
    And I wait for "div.chat.chat-start" to be visible
    Then "div.chat.chat-start" should be visible

  @wip
  Scenario: Chat without document context works from general page
    Given I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    When I wait for the page to load
    When I click "label[for='chat-drawer-global-chat-panel'][aria-label='Open chat']"
    And I wait for "div#chat-panel-content" to be visible
    And I select "${agentName}" from "select#agent-selector"
    And I fill "textarea#chat-input" with "What is Clean Architecture?"
    And I click the "Send" button
    And I wait for "div.chat.chat-start" to be visible
    Then "div.chat.chat-start" should be visible

  Scenario: Chat input enabled when agent is selected
    Given I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    When I wait for the page to load
    When I click "label[for='chat-drawer-global-chat-panel'][aria-label='Open chat']"
    And I wait for "div#chat-panel-content" to be visible
    And I select "${agentName}" from "select#agent-selector"
    Then "textarea#chat-input" should be enabled
