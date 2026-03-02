@browser
Feature: Session Completion Notifications in Dashboard
  As a platform user
  I want to receive in-app and browser notifications when my agent sessions complete, fail, or are cancelled
  So that I am informed about task outcomes even when I am not actively watching the session

  # The perme8_dashboard layout renders a notification bell in the topbar.
  # The sessions page at /sessions mounts AgentsWeb.SessionsLive.Index
  # inside the dashboard shell. When sessions complete, fail, or are cancelled,
  # the notification bell updates with session-specific notification types.
  #
  # The browser Notifications API hook requests permission on mount and shows
  # native desktop/mobile alerts when NotificationCreated events arrive.
  #
  # Authentication is handled via the Identity app — the browser logs in on
  # Identity's endpoint and the session cookie (_identity_key) is shared with
  # perme8_dashboard on the same domain (localhost).
  #
  # Seed data should provide:
  #   - A user with session_completed, session_failed, and session_cancelled notifications
  #
  # NOTE: Real-time event delivery (task completes -> notification appears)
  # cannot be tested from a single browser session. These scenarios verify
  # the UI rendering of seeded session notifications and browser notification
  # API permission handling.

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  # ---------------------------------------------------------------------------
  # Notification bell in dashboard topbar
  # ---------------------------------------------------------------------------

  Scenario: Notification bell is visible in dashboard topbar
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then "[data-testid='notification-bell']" should be visible

  # ---------------------------------------------------------------------------
  # In-app session notifications
  # ---------------------------------------------------------------------------

  Scenario: Session completion notification appears in notification bell
    # Seed precondition: user has a session_completed notification
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then "[data-testid='notification-badge']" should be visible
    When I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    Then "[data-testid='notification-item'][data-notification-type='session_completed']" should exist
    And I should see "Session completed"

  Scenario: Session failure notification appears in notification bell
    # Seed precondition: user has a session_failed notification
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then "[data-testid='notification-badge']" should be visible
    When I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    Then "[data-testid='notification-item'][data-notification-type='session_failed']" should exist
    And I should see "Session failed"

  Scenario: Session cancelled notification appears in notification bell
    # Seed precondition: user has a session_cancelled notification
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then "[data-testid='notification-badge']" should be visible
    When I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    Then "[data-testid='notification-item'][data-notification-type='session_cancelled']" should exist
    And I should see "Session cancelled"

  Scenario: Session notification types display correct icons
    # Seed precondition: user has completed, failed, and cancelled session notifications
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    And I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    Then "[data-testid='notification-item'][data-notification-type='session_completed'] [data-testid='notification-icon-success']" should be visible
    And "[data-testid='notification-item'][data-notification-type='session_failed'] [data-testid='notification-icon-error']" should be visible
    And "[data-testid='notification-item'][data-notification-type='session_cancelled'] [data-testid='notification-icon-cancelled']" should be visible

  Scenario: Session notification shows truncated instruction
    # Seed precondition: user has a session_completed notification with instruction data
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    And I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    Then "[data-testid='notification-item'][data-notification-type='session_completed']" should exist
    # The notification body should include a truncated version of the task instruction
    And "[data-testid='notification-item'][data-notification-type='session_completed']" should contain text "..."

  Scenario: Session failure notification shows error context
    # Seed precondition: user has a session_failed notification with error data
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    And I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    Then "[data-testid='notification-item'][data-notification-type='session_failed']" should exist
    And "[data-testid='notification-item'][data-notification-type='session_failed']" should contain text "Error"

  # ---------------------------------------------------------------------------
  # Browser Notifications API integration
  # ---------------------------------------------------------------------------

  Scenario: Browser notification permission is requested on page load
    # When the page mounts, the BrowserNotifications hook should request
    # Notification.requestPermission() if permission state is "default"
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then "[data-testid='browser-notification-requested']" should be visible

  Scenario: Browser notification shown when session completes and permission is granted
    # Seed precondition: permission is granted and a session notification arrives
    # The hook listens for push_event from the server and calls new Notification()
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    And I wait for "[data-testid='browser-notification-dispatched']" to be visible
    Then "[data-testid='browser-notification-dispatched']" should contain text "Session completed"

  Scenario: In-app notification bell still updates when browser permission is denied
    # Even if the user denies browser notification permission, the in-app
    # notification bell should still reflect new notifications
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then "[data-testid='browser-notification-dispatched']" should not exist
    And "[data-testid='notification-badge']" should be visible
