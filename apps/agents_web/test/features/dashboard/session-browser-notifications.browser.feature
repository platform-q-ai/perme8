@browser @sessions
Feature: Session browser notifications
  As a user running agent sessions
  I want browser notifications for terminal session updates
  So that I notice when a session completes or errors while the tab is in the background

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  Scenario: Background session completion raises a browser notification
    Given browser notifications are allowed for the site
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    When the sessions tab is in the background
    And a running session completes for the current user
    Then a browser notification should be shown with the session outcome

  Scenario: Background session failure raises a browser notification with the error
    Given browser notifications are allowed for the site
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    When the sessions tab is in the background
    And a running session fails for the current user with an error message
    Then a browser notification should be shown with the failure message
