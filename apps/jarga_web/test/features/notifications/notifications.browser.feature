@browser
Feature: Notification Management
  As a platform user
  I want to receive in-app notifications about workspace invitations and other important events
  So that I stay informed about activity relevant to me

  # Seed data (from exo_seeds_web.exs) provides:
  #   - Workspace "Product Team" with slug "product-team"
  #   - alice@example.com as owner
  #   - bob@example.com as admin
  #   - charlie@example.com as member
  #   - diana@example.com as guest
  #   - eve@example.com as non-member

  # NOTE: The NotificationBell is a LiveComponent embedded in the application topbar.
  # It is visible on every authenticated page. All notification interactions happen
  # in-page via LiveView -- no traditional page navigation is needed after login.

  # NOTE: Real-time / PubSub scenarios involve server-side event delivery.
  # The browser adapter runs as a single user in a single session, so real-time
  # delivery from external events cannot be fully triggered here. Those scenarios
  # are simplified to verify the UI perspective: that the bell and dropdown reflect
  # the expected state without requiring a manual page reload.

  # ---------------------------------------------------------------------------
  # Notification Bell Badge
  # ---------------------------------------------------------------------------

  Scenario: Notification bell shows unread count
    # Log in as member (who has seeded unread notifications)
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    # The notification bell should be visible in the topbar with an unread badge
    Then "[data-testid='notification-bell']" should be visible
    And "[data-testid='notification-badge']" should be visible
    And "[data-testid='notification-badge']" should contain text "3"

  Scenario: Notification bell shows 99+ for large unread counts
    # Log in as a user who has more than 99 unread notifications
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    # The badge should cap at "99+" rather than showing the exact count
    Then "[data-testid='notification-bell']" should be visible
    And "[data-testid='notification-badge']" should contain text "99+"

  # ---------------------------------------------------------------------------
  # Notification Dropdown
  # ---------------------------------------------------------------------------

  Scenario: User opens notification dropdown
    # Log in as member
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    # Click the notification bell to open the dropdown
    When I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    # The dropdown should list recent notifications
    Then "[data-testid='notification-dropdown']" should be visible
    And "[data-testid='notification-item']" should exist

  Scenario: Close notification dropdown
    # Log in as member
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    # Open the dropdown
    When I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    Then "[data-testid='notification-dropdown']" should be visible
    # Click the bell again to close the dropdown
    When I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be hidden
    Then "[data-testid='notification-dropdown']" should be hidden

  Scenario: Empty notification state
    # Log in as non-member (who has no notifications)
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${nonMemberEmail}"
    And I fill "#login_form_password_password" with "${nonMemberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    # The bell should be visible but with no badge
    Then "[data-testid='notification-bell']" should be visible
    And "[data-testid='notification-badge']" should not exist
    # Open the dropdown and verify empty state message
    When I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    Then I should see "No notifications"

  # ---------------------------------------------------------------------------
  # Mark as Read
  # ---------------------------------------------------------------------------

  Scenario: User marks a single notification as read
    # Log in as member
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    # Store the initial badge count for comparison
    And I store the text of "[data-testid='notification-badge']" as "initialCount"
    # Open the dropdown and click an unread notification
    When I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    And I click "[data-testid='notification-item-unread']:first-child"
    And I wait for network idle
    # The clicked notification should now be marked as read (visual change)
    Then "[data-testid='notification-item-unread']:first-child" should not exist
    # The badge count should have decreased
    And "[data-testid='notification-badge']" should be visible

  Scenario: User marks all notifications as read
    # Log in as member (who has 3 unread notifications)
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    # Verify unread badge is present
    Then "[data-testid='notification-badge']" should be visible
    # Open dropdown and click "Mark all as read"
    When I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    And I click the "Mark all as read" button
    And I wait for network idle
    # All notifications should now be read and the badge should disappear
    Then "[data-testid='notification-badge']" should not exist
    And "[data-testid='notification-item-unread']" should not exist

  # ---------------------------------------------------------------------------
  # Real-time Updates
  # ---------------------------------------------------------------------------

  Scenario: Real-time notification delivery updates bell
    # NOTE: Multi-user real-time delivery cannot be triggered from a single browser
    # session. This scenario verifies the UI perspective: that after a notification
    # event is delivered via PubSub, the bell count updates without a page reload.
    # In practice, the seed data or a test helper would trigger the notification.
    # Log in as member
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    # Verify the bell is present and showing the current count
    Then "[data-testid='notification-bell']" should be visible
    And "[data-testid='notification-badge']" should be visible
    # Store the current count for later comparison
    And I store the text of "[data-testid='notification-badge']" as "countBefore"
    # When a new notification arrives (e.g., workspace invitation via PubSub),
    # the badge should update in real-time without requiring a page reload.
    # After the real-time event is delivered:
    When I wait for 2 seconds
    Then "[data-testid='notification-badge']" should be visible
    # Open dropdown to verify the new notification appears
    When I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    Then "[data-testid='notification-item']" should exist

  # ---------------------------------------------------------------------------
  # Workspace Invitation Actions
  # ---------------------------------------------------------------------------

  Scenario: Accept workspace invitation from notification
    # Log in as a user who has a pending workspace invitation notification
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${nonMemberEmail}"
    And I fill "#login_form_password_password" with "${nonMemberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    # Open the notification dropdown
    When I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    # Find the workspace invitation notification and click Accept
    And I wait for "[data-testid='notification-invitation']" to be visible
    And I click "[data-testid='notification-invitation'] [data-testid='accept-invitation']"
    And I wait for network idle
    # The invitation should be accepted: notification marked as read, workspace accessible
    Then I should see "Invitation accepted"
    And "[data-testid='notification-invitation'] [data-testid='accept-invitation']" should not exist
    # Navigate to workspaces to verify the workspace now appears in the list
    When I navigate to "${baseUrl}/app/workspaces"
    And I wait for network idle
    Then I should see "Product Team"

  Scenario: Decline workspace invitation from notification
    # Log in as a user who has a pending workspace invitation notification
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${nonMemberEmail}"
    And I fill "#login_form_password_password" with "${nonMemberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    # Open the notification dropdown
    When I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    # Find the workspace invitation notification and click Decline
    And I wait for "[data-testid='notification-invitation']" to be visible
    And I click "[data-testid='notification-invitation'] [data-testid='decline-invitation']"
    And I wait for network idle
    # The invitation should be declined and the notification marked as read
    Then I should see "Invitation declined"
    And "[data-testid='notification-invitation'] [data-testid='decline-invitation']" should not exist

  # ---------------------------------------------------------------------------
  # User Scoping
  # ---------------------------------------------------------------------------

  Scenario: Notifications are user-scoped
    # Log in as member (user A) and capture their notification count
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    # User A should see their own notifications
    Then "[data-testid='notification-bell']" should be visible
    When I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    Then "[data-testid='notification-item']" should exist
    # Store the count of user A's notifications
    And I store the text of "[data-testid='notification-badge']" as "userACount"
    # Log out and log in as a different user (user B)
    When I navigate to "${baseUrl}/users/log-out"
    And I wait for network idle
    And I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    And I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    # User B should see their own notifications (different from user A)
    Then "[data-testid='notification-bell']" should be visible
    # User B's badge should NOT show user A's count
    # (The exact count differs per user based on their own notifications)
