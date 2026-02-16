@browser @chat @streaming
Feature: Chat Streaming Responses
  As a user
  I want to see agent responses stream in real-time
  So that I get immediate feedback and can see the agent thinking process

  # Streaming requires an actual LLM response. Most scenarios are tagged @wip
  # because they depend on a live LLM backend. The "Thinking..." indicator
  # appears during streaming. Cancel button appears during streaming with
  # phx-click="cancel_streaming".

  Background:
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for the page to load
    Given I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    When I wait for the page to load
    When I click "label[for='chat-drawer-global-chat-panel'][aria-label='Open chat']"
    And I wait for "div#chat-panel-content" to be visible

  @wip
  Scenario: Thinking indicator appears while waiting for response
    When I fill "textarea#chat-input" with "Explain Clean Architecture"
    And I click the "Send" button
    Then I should see "Thinking..."

  @wip
  Scenario: Send button disabled during streaming
    When I fill "textarea#chat-input" with "Tell me about TDD"
    And I click the "Send" button
    And I wait for 1 seconds
    Then "#chat-message-form button[type='submit']" should be disabled

  @wip
  Scenario: Cancel button appears during streaming
    When I fill "textarea#chat-input" with "Write a long explanation of programming"
    And I click the "Send" button
    And I wait for 1 seconds
    Then I should see "Cancel"

  @wip
  Scenario: Cancel streaming stops the response
    When I fill "textarea#chat-input" with "Write a very detailed explanation of all programming paradigms"
    And I click the "Send" button
    And I wait for 1 seconds
    When I click the "Cancel" button
    And I wait for 1 seconds
    Then "textarea#chat-input" should be enabled
    And I should not see "Thinking..."

  @wip
  Scenario: Streaming response completes and re-enables input
    When I fill "textarea#chat-input" with "What is TDD?"
    And I click the "Send" button
    And I wait for "div.chat.chat-start" to be visible
    Then "textarea#chat-input" should be enabled
    And I should not see "Thinking..."

  @wip
  Scenario: Completed streaming response persists after page reload
    When I fill "textarea#chat-input" with "What is TDD?"
    And I click the "Send" button
    And I wait for "div.chat.chat-start" to be visible
    Given I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    When I wait for the page to load
    When I click "label[for='chat-drawer-global-chat-panel'][aria-label='Open chat']"
    And I wait for "div#chat-panel-content" to be visible
    Then I should see "TDD"
