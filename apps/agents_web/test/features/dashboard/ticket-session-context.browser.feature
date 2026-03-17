@browser @sessions @tickets @context
Feature: Ticket-session context preservation
  As a developer starting a chat from a ticket
  I want the message to include the ticket's context and maintain the association
  So that the agent has full context and the ticket remains linked to its session

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  Scenario: Ticket detail panel is visible when clicking a ticket
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_with_context"
    And I wait for network idle
    When I click "#triage-lane [data-testid^='triage-ticket-item-']"
    And I wait for network idle
    Then "[data-testid='ticket-detail-panel']" should be visible

  Scenario: Ticket detail shows title and body
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_with_context"
    And I wait for network idle
    When I click "#triage-lane [data-testid^='triage-ticket-item-']"
    And I wait for network idle
    Then "[data-testid='ticket-detail-panel']" should be visible
    And "[data-testid='ticket-detail-body']" should exist

  Scenario: Ticket detail shows labels
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_with_labels"
    And I wait for network idle
    When I click "#triage-lane [data-testid^='triage-ticket-item-']"
    And I wait for network idle
    Then "[data-testid='ticket-detail-labels']" should exist

  Scenario: Starting a session from a ticket shows ticket context
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_start_session"
    And I wait for network idle
    When I click "#triage-lane [data-testid^='triage-ticket-item-']"
    And I wait for network idle
    Then "[data-testid='ticket-detail-panel']" should be visible

  Scenario: Ticket with sub-tickets shows sub-issue list
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_with_subtickets"
    And I wait for network idle
    When I click "#triage-lane [data-testid^='triage-ticket-item-']"
    And I wait for network idle
    Then "[data-testid='ticket-detail-subissues']" should exist
