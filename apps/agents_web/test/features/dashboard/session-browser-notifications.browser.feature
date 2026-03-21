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

  Scenario: Sessions page prompts for notification permission
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then "#browser-notifications-permission-prompt" should exist
    And the page should contain "Enable browser notifications"

  Scenario: Background session completion raises a browser notification
    Given browser notifications are allowed for the site
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    When a running session completes for the current user
    And the sessions tab is in the background
    Then a browser notification should be shown with the session outcome

  Scenario: Background session failure raises a browser notification with the error
    Given browser notifications are allowed for the site
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    When a running session fails for the current user with an error message
    And the sessions tab is in the background
    Then a browser notification should be shown with the failure message
