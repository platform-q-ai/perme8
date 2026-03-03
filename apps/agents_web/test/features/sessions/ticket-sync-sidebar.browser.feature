@browser @sessions @ticket-sync
Feature: GitHub ticket sync sidebar in Sessions
  As an authenticated user
  I want the Sessions sidebar to show synced project ticket state
  So that I can pick work from Backlog and Ready issues

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle

  Scenario: Empty ticket sidebar explains no Backlog or Ready tickets
    Then I should see "No Backlog or Ready tickets"
    And "[data-testid^='ticket-item-']" should not exist

  Scenario: Auth refresh bulk action is hidden without failed auth tickets
    Then "button[phx-click='refresh_all_auth']" should not exist

  Scenario: Sidebar section headers are visible for ticket-driven workflow
    Then I should see "Tickets"
    And I should see "Sessions"
