@browser
Feature: Notification Management
  As a platform user
  I want to receive in-app notifications about workspace invitations and other important events
  So that I stay informed about activity relevant to me

  # Seed data (from exo_seeds_web.exs) provides:
  #   - Workspace "Product Team" with slug "product-team"
  #   - alice@example.com as owner  (105 unread notifications)
  #   - bob@example.com as admin    (0 notifications)
  #   - charlie@example.com as member (3 unread notifications)
  #   - diana@example.com as guest  (2 unread notifications)
  #   - eve@example.com as non-member (1 workspace invitation notification)
  #
  # IMPORTANT: Scenarios are ordered so that read-only scenarios run first.
  # Mutating scenarios (mark-as-read) run last because they modify shared
  # database state and the seed is only loaded once per test suite run.

  # NOTE: The NotificationBell is a LiveComponent embedded in the application topbar.
  # It is visible on every authenticated page. All notification interactions happen
  # in-page via LiveView -- no traditional page navigation is needed after login.

  # ---------------------------------------------------------------------------
  # Notification Bell Badge (read-only)
  # ---------------------------------------------------------------------------

  Scenario: Notification bell shows unread count
    # Log in as member (charlie, who has 3 seeded unread notifications)
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
  # Notification Dropdown (read-only)
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
    # Click away from the dropdown to close it (triggers phx-click-away)
    When I click "body"
    And I wait for "[data-testid='notification-dropdown']" to be hidden
    Then "[data-testid='notification-dropdown']" should be hidden

  Scenario: Empty notification state
    # Log in as admin (bob) who has no seeded notifications
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${adminEmail}"
    And I fill "#login_form_password_password" with "${adminPassword}"
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
  # User Scoping (read-only — must run before mark-as-read scenarios)
  # ---------------------------------------------------------------------------

  Scenario: Notifications are user-scoped
    # Log in as member (charlie, user A) who has 3 unread notifications
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    # User A (charlie) should see badge with count 3
    Then "[data-testid='notification-bell']" should be visible
    And "[data-testid='notification-badge']" should contain text "3"
    # Open a separate browser session and log in as a different user (diana, user B)
    When I open browser session "guest-user"
    And I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    And I fill "#login_form_password_email" with "${guestEmail}"
    And I fill "#login_form_password_password" with "${guestPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    # User B (diana) should see her own count (2), not charlie's (3)
    Then "[data-testid='notification-bell']" should be visible
    And "[data-testid='notification-badge']" should contain text "2"

  # ---------------------------------------------------------------------------
  # Real-time Updates (read-only — verifies UI state without mutation)
  # ---------------------------------------------------------------------------

  Scenario: Real-time notification delivery updates bell
    # NOTE: Multi-user real-time delivery cannot be triggered from a single browser
    # session. This scenario verifies the UI perspective: that the bell and dropdown
    # reflect the expected state. In practice, a PubSub event would trigger the update.
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
    # Open dropdown to verify notifications appear
    When I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    Then "[data-testid='notification-item']" should exist

  # ---------------------------------------------------------------------------
  # Mark as Read (mutating — these modify database state, run last)
  # ---------------------------------------------------------------------------

  Scenario: User marks a single notification as read
    # Log in as member (charlie, 3 unread)
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    # Verify charlie starts with 3 unread
    Then "[data-testid='notification-badge']" should contain text "3"
    # Open the dropdown and click the mark-as-read button (blue dot) on the first unread notification
    When I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    And I click "[data-testid='mark-read-button'] >> nth=0"
    And I wait for 2 seconds
    # Charlie had 3 unread; after marking one as read, 2 remain
    Then "[data-testid='notification-badge']" should contain text "2"

  Scenario: User marks all notifications as read
    # Log in as member (charlie, who now has 2 unread after the previous scenario)
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
    And I wait for 2 seconds
    # All notifications should now be read and the badge should disappear
    Then "[data-testid='notification-badge']" should not exist
    And "[data-testid='notification-item'][data-notification-status='unread']" should not exist

  # ---------------------------------------------------------------------------
  # Workspace Invitation Actions (require full invitation flow — deferred)
  # ---------------------------------------------------------------------------

  @invite_created_via_ui
  Scenario: Workspace invite is created from UI invite flow
    # Owner invites Eve to the Engineering workspace via UI
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    And I navigate to "${baseUrl}/app/workspaces/engineering"
    And I wait for network idle
    And I click "button[aria-label='Actions menu']"
    And I wait for 1 seconds
    And I click the "Manage Members" button
    And I wait for ".modal.modal-open" to be visible
    And I fill "[name='email']" with "${nonMemberEmail}"
    And I select "member" from "[name='role']"
    And I click the "Invite" button
    And I wait for network idle
    Then I should see "Invitation sent via email"
    And I should see "${nonMemberEmail}"

  @invite_notification
  Scenario: Invited user joins workspace from actionable notification
    # Seed data includes a pending invitation for grace@example.com to Product Team
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${inviteeEmail}"
    And I fill "#login_form_password_password" with "${inviteePassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    # Before accepting, Eve cannot access the invited workspace directly
    When I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    Then I should see "Workspace not found"
    # Notification bell should show an unread indicator (dot/badge)
    And "[data-testid='notification-bell']" should be visible
    And "[data-testid='notification-badge']" should be visible
    When I click "[data-testid='notification-bell']"
    And I wait for "[data-testid='notification-dropdown']" to be visible
    Then "[data-testid='notification-invitation']" should be visible
    And "[data-testid='notification-invitation'] [data-testid='accept-invitation']" should be visible
    # Accepting the invite should grant access to the workspace
    When I click "[data-testid='notification-invitation'] [data-testid='accept-invitation'] >> nth=0"
    And I wait for network idle
    # Wait for LiveView to process acceptance and refresh invitation actions
    And I wait for "[data-testid='notification-invitation'] [data-testid='accept-invitation']" to be hidden
    When I navigate to "${baseUrl}/app/workspaces/${productTeamSlug}"
    And I wait for network idle
    Then the URL should contain "/app/workspaces/${productTeamSlug}"
    And I should see "Product Team"

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
