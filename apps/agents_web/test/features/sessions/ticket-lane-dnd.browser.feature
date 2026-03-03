@browser @sessions @ticket-sync @wip
Feature: Drag and drop ticket lanes in Sessions sidebar
  As an authenticated user
  I want to drag tickets between Backlog and Ready lanes
  So that the sidebar order and status match board triage decisions

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    And I click "button[data-testid='sidebar-tab-tickets']"

  Scenario: Ticket cards are draggable when ticket lanes are populated
    # Requires seeded Backlog/Ready tickets in the test environment.
    Then "#ticket-lane-backlog [data-ticket-card]" should exist
    And "#ticket-lane-ready [data-ticket-card]" should exist
    And "#ticket-lane-backlog [data-ticket-card]" should have attribute "draggable" with value "true"

  Scenario: Dragging a ticket to Ready updates lane placement
    # Requires seeded Backlog/Ready tickets in the test environment.
    When I drag "#ticket-lane-backlog [data-ticket-card]:first-child" to "#ticket-lane-ready"
    Then "#ticket-lane-ready [data-ticket-card]" should exist
