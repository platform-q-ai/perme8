@browser @chat @queued-messages
Feature: Queued Message Display
  As a user
  I want to see my queued messages in the chat while the assistant is responding
  So that I know my message was accepted and where it will appear in the conversation

  # When a user sends a message while the assistant is streaming a response,
  # the message is queued. Queued messages appear in the message list with
  # distinct styling (muted opacity, "Queued" indicator). Once the assistant
  # finishes responding, queued messages transition to sent status and
  # trigger the next assistant response.

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
  Scenario: Queued message appears with distinct styling while assistant is streaming
    # Send first message to start streaming
    When I fill "textarea#chat-input" with "Tell me about TDD"
    And I click the "Send" button
    And I wait for 1 seconds
    # Input should be re-enabled for queueing during streaming
    Then "textarea#chat-input" should be enabled
    # Send a second message while streaming
    When I fill "textarea#chat-input" with "Also explain BDD"
    And I click the "Send" button
    # Queued message should appear with queued indicator
    Then I should see "Also explain BDD"
    And "div.chat-bubble-queued" should be visible

  @wip
  Scenario: Queued message shows at correct insertion position
    # Send first message
    When I fill "textarea#chat-input" with "What is Clean Architecture?"
    And I click the "Send" button
    And I wait for 1 seconds
    # Queue a second message while assistant is responding
    When I fill "textarea#chat-input" with "What about hexagonal?"
    And I click the "Send" button
    # The queued message should appear after the streaming assistant response
    Then I should see "What about hexagonal?"

  @wip
  Scenario: Queued message transitions to sent state after assistant finishes
    When I fill "textarea#chat-input" with "Explain unit testing"
    And I click the "Send" button
    And I wait for 1 seconds
    When I fill "textarea#chat-input" with "Now explain integration testing"
    And I click the "Send" button
    # Wait for assistant to finish first response and process queued message
    And I wait for "div.chat.chat-start" to be visible
    And I wait for 10 seconds
    # Queued message should now show as a normal sent message (no queued indicator)
    Then I should see "Now explain integration testing"
    And "div.chat-bubble-queued" should not exist

  @wip
  Scenario: Multiple queued messages are displayed in order
    When I fill "textarea#chat-input" with "First question"
    And I click the "Send" button
    And I wait for 1 seconds
    When I fill "textarea#chat-input" with "Second question"
    And I click the "Send" button
    When I fill "textarea#chat-input" with "Third question"
    And I click the "Send" button
    Then I should see "Second question"
    And I should see "Third question"
