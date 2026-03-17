@browser @sessions @queued-messages
Feature: Queued Messages in Sessions
  As a user
  I want to see my queued messages while the agent is still processing
  So that I have visibility into what messages are pending

  # When a task is running, messages sent to the agent are queued by
  # opencode until the agent finishes its current work. These scenarios
  # verify that queued messages are displayed in the session output log
  # with distinct visual styling and clear insertion position.
  #
  # NOTE: Actual task execution requires Docker + opencode and cannot be
  # tested end-to-end in browser tests. The form placeholder scenario can
  # run without Docker.

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  # ---------------------------------------------------------------------------
  # Queued message visibility
  # ---------------------------------------------------------------------------

  Scenario: Queued message appears in output log after sending
    Given I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    # Assume a session exists with a running task
    When I fill "textarea#session-instruction" with "Follow-up instruction"
    And I click "form#session-form button[type='submit']"
    And I wait for 1 seconds
    Then I should see "Follow-up instruction"
    And I should see "Queued"

  # Scenario: Queued message has muted visual styling — removed, data-testid='queued-message' not yet implemented (see #488)

  Scenario: Multiple queued messages shown in submission order
    Given I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    When I fill "textarea#session-instruction" with "First queued message"
    And I click "form#session-form button[type='submit']"
    And I wait for 1 seconds
    When I fill "textarea#session-instruction" with "Second queued message"
    And I click "form#session-form button[type='submit']"
    And I wait for 1 seconds
    Then I should see "First queued message"
    And I should see "Second queued message"

  Scenario: Queued messages persist when task is cancelled
    Given I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    When I fill "textarea#session-instruction" with "Message still visible after cancel"
    And I click "form#session-form button[type='submit']"
    And I wait for 1 seconds
    Then I should see "Message still visible after cancel"
    And I should see "Queued"
    When I click "#cancel-task-btn"
    And I wait for 1 seconds
    Then I should see "Message still visible after cancel"
    And I should see "Queued"

  # ---------------------------------------------------------------------------
  # Form behaviour during running task
  # ---------------------------------------------------------------------------

  Scenario: Sidebar quick-start form is visible without extra action
    Given I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then "form#sidebar-new-ticket-form" should exist
    And "textarea#sidebar-new-ticket-instruction[placeholder='Add a ticket...']" should exist
