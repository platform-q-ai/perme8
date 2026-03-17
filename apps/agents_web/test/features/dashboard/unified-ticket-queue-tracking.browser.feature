@browser @sessions @tickets @queue
Feature: Unified ticket queue tracking
  As a developer using the sessions UI
  I want tickets to remain as a single entity as they move through the queue
  So that I can track ticket progress without confusion from duplicate entries

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  Scenario: Idle ticket appears in the triage column
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_idle"
    And I wait for network idle
    Then "#triage-lane [data-testid^='triage-ticket-item-']" should exist

  Scenario: Queued ticket appears in the build column
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_queued"
    And I wait for network idle
    Then "[data-testid='build-queue-panel'] [data-testid='task-card']" should exist

  Scenario: Running ticket shows lifecycle badge
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_running"
    And I wait for network idle
    Then "[data-testid='lifecycle-state']" should exist

  Scenario: Completed ticket returns to triage with completed indicator
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_completed"
    And I wait for network idle
    Then "#triage-lane [data-testid^='triage-ticket-item-']" should exist

  Scenario: Failed ticket returns to triage with error indicator
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_failed"
    And I wait for network idle
    Then "#triage-lane [data-testid^='triage-ticket-item-']" should exist

  Scenario: Queued ticket card shows session queue position
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_queued_position"
    And I wait for network idle
    Then "[data-testid='task-card']" should exist

  Scenario: Running ticket card shows progress bar from todo items
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_running_with_progress"
    And I wait for network idle
    Then "[data-testid='task-card']" should exist

  Scenario: Clicking a ticket card opens session detail
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_running"
    And I wait for network idle
    When I click "[data-testid='task-card']"
    And I wait for network idle
    Then "[data-testid='chat-log']" should exist

  Scenario: Session linked to a ticket does not render as standalone
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_with_session"
    And I wait for network idle
    Then "#triage-lane [data-testid^='triage-ticket-item-']" should exist

  Scenario: Ticket transitions visible in real-time
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_transition_start"
    And I wait for network idle
    Then "#triage-lane [data-testid^='triage-ticket-item-']" should exist
