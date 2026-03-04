@browser @sessions @ticket-sync
Feature: GitHub ticket sync sidebar in Sessions
  As an authenticated user
  I want the Sessions sidebar to show synced project tickets in the triage column
  So that I can pick work from project issues

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle

  Scenario: Triage column shows Tickets divider when tickets exist
    # Requires seeded tickets in the test environment.
    Then I should see "Tickets"
    And "[data-testid^='triage-ticket-item-']" should exist

  Scenario: Auth refresh bulk action is hidden without failed auth tickets
    Then "button[phx-click='refresh_all_auth']" should not exist

  Scenario: Builds header is visible in the build column
    Then I should see "Builds"
