@browser @chat @queued-messages
Feature: Chat Queued Messages
  As a user
  I want to queue messages while the assistant is streaming
  So that I can continue my thought process without waiting for the current response

  # When the assistant is streaming, the user can still type and send messages.
  # Queued messages appear in the chat with a "Queued" indicator and muted styling.
  # Once streaming completes, queued messages are processed sequentially.
  # Cancel streaming discards all queued messages.

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

  @wip
  Scenario: Input remains enabled during streaming
    When I fill "textarea#chat-input" with "First message"
    And I click the "Send" button
    And I wait for 1 seconds
    Then "textarea#chat-input" should be enabled

  @wip
  Scenario: Queue a message while assistant is streaming
    When I fill "textarea#chat-input" with "First message"
    And I click the "Send" button
    And I wait for 1 seconds
    When I fill "textarea#chat-input" with "Second message (queued)"
    And I click the "Send" button
    Then I should see "Second message (queued)"
    And I should see "Queued"

  @wip
  Scenario: Queued message transitions to sent after streaming completes
    When I fill "textarea#chat-input" with "First message"
    And I click the "Send" button
    And I wait for 1 seconds
    When I fill "textarea#chat-input" with "Queued follow-up"
    And I click the "Send" button
    And I wait for "div.chat.chat-start" to be visible
    And I wait for 5 seconds
    Then I should see "Queued follow-up"
    And I should not see "Queued"

  @wip
  Scenario: Multiple queued messages shown in order
    When I fill "textarea#chat-input" with "First message"
    And I click the "Send" button
    And I wait for 1 seconds
    When I fill "textarea#chat-input" with "Queued message one"
    And I click the "Send" button
    When I fill "textarea#chat-input" with "Queued message two"
    And I click the "Send" button
    Then I should see "Queued message one"
    And I should see "Queued message two"

  @wip
  Scenario: Cancel streaming discards queued messages
    When I fill "textarea#chat-input" with "First message"
    And I click the "Send" button
    And I wait for 1 seconds
    When I fill "textarea#chat-input" with "This will be discarded"
    And I click the "Send" button
    Then I should see "This will be discarded"
    When I click the "Cancel" button
    And I wait for 1 seconds
    Then I should not see "This will be discarded"
    And I should not see "Queued"
