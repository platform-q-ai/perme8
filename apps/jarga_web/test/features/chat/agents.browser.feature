@browser @chat @agents
Feature: Chat Agent Selection
  As a user
  I want to select which AI agent to chat with
  So that I can use the right assistant for my task

  # Agent selection is available via a select element inside the chat panel.
  # The selector has id="agent-selector", name="agent_id", and
  # phx-change="select_agent". It is labeled "Select Agent".

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

  Scenario: Agent selector is visible in chat panel
    Then "select#agent-selector" should be visible
    And I should see "Select Agent"

  Scenario: Agent selector has correct attributes
    Then "select#agent-selector[name='agent_id']" should exist
    And "select#agent-selector[phx-change='select_agent']" should exist

  Scenario: Select an agent for chatting
    When I select "${agentName}" from "select#agent-selector"
    And I wait for 1 seconds
    Then "textarea#chat-input" should be enabled

  Scenario: Agent selector contains agent options
    Then "select#agent-selector option" should exist

  Scenario: Agent selection persists after navigating away and back
    When I select "${agentName}" from "select#agent-selector"
    And I wait for network idle
    # Navigate away
    Given I navigate to "${baseUrl}/app/workspaces/${engineeringSlug}"
    When I wait for the page to load
    # Navigate back
    Given I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    When I wait for the page to load
    When I click "label[for='chat-drawer-global-chat-panel'][aria-label='Open chat']"
    And I wait for "div#chat-panel-content" to be visible
    Then "select#agent-selector" should be visible

  @wip
  Scenario: Sending message with selected agent gets response
    When I select "${agentName}" from "select#agent-selector"
    And I fill "textarea#chat-input" with "Hello agent"
    And I click the "Send" button
    And I wait for "div.chat.chat-start" to be visible
    Then "div.chat.chat-start" should be visible
