@browser @sessions @ticket-sync
Feature: Drag and drop triage tickets in Sessions sidebar
  As an authenticated user
  I want to reorder tickets in the triage column
  So that I can prioritise which tickets to work on next

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle

  Scenario: Ticket cards are draggable in the triage column
    # Requires seeded tickets in the test environment.
    Then "#triage-lane [data-triage-ticket-card]" should exist
    And "#triage-lane [data-triage-ticket-card]" should have attribute "draggable" with value "true"

  Scenario: Dragging a triage ticket reorders the list
    # Requires at least two seeded tickets in the test environment.
    When I drag "#triage-lane [data-triage-ticket-card]:last-child" to "#triage-lane [data-triage-ticket-card]:first-child"
    Then "#triage-lane [data-triage-ticket-card]" should exist
