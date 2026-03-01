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
    And I wait for network idle
    Given I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    When I click ".drawer-content > .navbar label[for='chat-drawer-global-chat-panel']"
    And I wait for "div#chat-panel-content" to be visible

  Scenario: Agent selector is visible in chat panel
    Then "select#agent-selector" should be visible
    And I should see "Select Agent"

  Scenario: Agent selector has correct attributes
    Then "select#agent-selector[name='agent_id']" should exist
    And "form[phx-change='select_agent'] select#agent-selector" should exist

  Scenario: Select an agent for chatting
    When I select "${agentName}" from "select#agent-selector"
    And I wait for 1 seconds
    Then "textarea#chat-input" should be enabled

  Scenario: Agent selector contains agent options
    Then "select#agent-selector option" should exist

  @wip
  Scenario: Agent selection persists after navigating away and back
    When I select "${agentName}" from "select#agent-selector"
    And I wait for network idle
    # Navigate away
    Given I navigate to "${baseUrl}/app/workspaces/${engineeringSlug}"
    And I wait for network idle
    # Navigate back
    Given I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    When I click ".drawer-content > .navbar label[for='chat-drawer-global-chat-panel']"
    And I wait for "div#chat-panel-content" to be visible
    Then "select#agent-selector" should be visible

  @wip
  Scenario: Sending message with selected agent gets response
    When I select "${agentName}" from "select#agent-selector"
    And I fill "textarea#chat-input" with "Hello agent"
    And I click the "Send" button
    And I wait for "div.chat.chat-start" to be visible
    Then "div.chat.chat-start" should be visible
