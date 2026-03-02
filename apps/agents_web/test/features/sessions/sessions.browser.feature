@browser @sessions
Feature: Coding Sessions Management
  As a user
  I want to view and manage coding sessions
  So that I can run tasks in containers and track their progress

  # The Sessions page lives at /sessions on the agents_web endpoint.
  # It uses a split-pane layout: session list on the left, session detail
  # on the right. The sidebar always includes a quick-start textarea for
  # creating new sessions. When no sessions exist, an empty state is shown
  # in the detail panel.
  #
  # Authentication is handled via the Identity app — the browser logs in on
  # Identity's endpoint and the session cookie (_identity_key) is shared with
  # agents_web on the same domain (localhost).
  #
  # NOTE: Actual task execution requires Docker + opencode and cannot be
  # tested end-to-end in browser tests. These scenarios cover the UI
  # structure, empty state display, and form validation.

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  # ---------------------------------------------------------------------------
  # Page Structure
  # ---------------------------------------------------------------------------

  Scenario: Sessions page renders sidebar quick-start form
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then "form#sidebar-new-session-form" should exist
    And "textarea#sidebar-new-session-instruction" should exist

  Scenario: Sessions page shows empty state when no sessions exist
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then I should see "No sessions yet"

  # ---------------------------------------------------------------------------
  # Instruction Forms
  # ---------------------------------------------------------------------------

  Scenario: Sidebar quick-start textarea has placeholder text
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then "textarea#sidebar-new-session-instruction[placeholder='Start a new session...']" should exist

  Scenario: Empty state still shows sidebar quick-start textarea
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then "form#sidebar-new-session-form" should exist
    And "textarea#sidebar-new-session-instruction" should exist
