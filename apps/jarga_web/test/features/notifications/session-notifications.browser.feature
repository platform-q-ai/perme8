@browser
Feature: Session Completion Notifications
  As a platform user
  I want to receive in-app and browser notifications when my agent sessions complete, fail, or are cancelled
  So that I am informed about task outcomes even when I am not actively watching the session

  # Early-pipeline notes:
  # - This file focuses only on session notification behavior and browser Notifications API integration.
  # - Existing bell/dropdown basics are covered in notifications.browser.feature and are not duplicated here.
  # - Seed/setup for these scenarios should provide session notification fixtures for the logged-in user.

  # ---------------------------------------------------------------------------
  # Authentication for protected notification behavior
  # ---------------------------------------------------------------------------

  Scenario: Authenticated user can access session notifications
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    Then "[data-testid='notification-bell']" should be visible

  Scenario: Login with invalid credentials does not grant access
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "invalid@example.com"
    And I fill "#login_form_password_password" with "wrong-password"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    Then the URL should contain "/users/log-in"
    And I should see "Invalid email or password"

  Scenario: Unauthenticated user is redirected to login before viewing notifications
    Given I navigate to "${baseUrl}/app"
    And I wait for network idle
    Then the URL should contain "/users/log-in"

  # ---------------------------------------------------------------------------
  # In-app session notifications
  # ---------------------------------------------------------------------------

  Scenario: Session completion notification appears in notification bell
    # Seed precondition: user has a newly completed owned session notification.
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    Then "[data-testid='notification-badge']" should be visible
    When I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    Then I should see "Session completed"
    And "[data-testid='notification-item'][data-notification-type='session_completed']" should exist
    And "[data-testid='notification-item'][data-notification-type='session_completed']" should contain text "Completed"
    And "[data-testid='notification-item'][data-notification-type='session_completed']" should contain text "..."

  Scenario: Session failure notification appears in notification bell
    # Seed precondition: user has a newly failed owned session notification.
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    Then "[data-testid='notification-badge']" should be visible
    When I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    Then I should see "Session failed"
    And "[data-testid='notification-item'][data-notification-type='session_failed']" should exist
    And "[data-testid='notification-item'][data-notification-type='session_failed']" should contain text "Error"

  Scenario: Session cancelled notification appears in notification bell
    # Seed precondition: user has a newly cancelled owned session notification.
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    Then "[data-testid='notification-badge']" should be visible
    When I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    Then I should see "Session cancelled"
    And "[data-testid='notification-item'][data-notification-type='session_cancelled']" should exist

  Scenario: Session notification types display correct icons
    # Seed precondition: user has completed, failed, and cancelled session notifications.
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    And I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    Then "[data-testid='notification-item'][data-notification-type='session_completed'] [data-testid='notification-icon-success']" should be visible
    And "[data-testid='notification-item'][data-notification-type='session_failed'] [data-testid='notification-icon-error']" should be visible
    And "[data-testid='notification-item'][data-notification-type='session_cancelled'] [data-testid='notification-icon-cancelled']" should be visible

  # ---------------------------------------------------------------------------
  # Browser Notifications API integration
  # ---------------------------------------------------------------------------

  Scenario: Browser notification permission is requested on page load
    # Seed precondition: browser notification permission state is default (not yet granted or denied).
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    Then "[data-testid='notification-permission-requested']" should be visible

  Scenario: Browser notification shown when session completes and permission is granted
    # Seed precondition: permission is granted and a completed session notification arrives in real time.
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    And I wait for "[data-testid='browser-notification-dispatched']" to be visible
    Then "[data-testid='browser-notification-dispatched']" should contain text "Session completed"
    And "[data-testid='browser-notification-dispatched']" should contain text "instruction"

  Scenario: Browser notification not shown when permission is denied
    # Seed precondition: permission is denied and a completed session notification arrives in real time.
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    Then "[data-testid='browser-notification-dispatched']" should not exist
    And "[data-testid='notification-badge']" should be visible
