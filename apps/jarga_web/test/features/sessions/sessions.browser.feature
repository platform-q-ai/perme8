@browser @sessions
Feature: Coding Sessions Management
  As a user
  I want to view and manage coding sessions
  So that I can run tasks in ephemeral containers and track their progress

  # The Sessions page lives at /app/sessions (LiveView).
  # It shows an instruction form with a Run button, an event log (when a task
  # is active), and a task history table with colour-coded status badges.
  #
  # Seed data: alice@example.com (owner) has three seeded tasks:
  #   - "Write unit tests for auth" (completed)
  #   - "Refactor database queries" (failed)
  #   - "Add API endpoint for users" (pending)
  #
  # NOTE: Actual task execution requires Docker + opencode and cannot be
  # tested end-to-end in browser tests. These scenarios cover the UI
  # structure, navigation, form validation, and seeded data display.

  Background:
    Given I am on "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  # ---------------------------------------------------------------------------
  # Page Structure & Navigation
  # ---------------------------------------------------------------------------

  Scenario: Sessions page renders heading and subtitle
    When I navigate to "${baseUrl}/app/sessions"
    And I wait for network idle
    Then I should see "Sessions"
    And I should see "Run coding tasks in ephemeral containers"

  Scenario: Navigate to sessions via sidebar link
    When I navigate to "${baseUrl}/app"
    And I wait for network idle
    And I click the "Sessions" link
    And I wait for network idle
    Then the URL should contain "/app/sessions"
    And I should see "Sessions"

  Scenario: Sidebar shows Sessions navigation item
    When I navigate to "${baseUrl}/app/sessions"
    And I wait for network idle
    Then "a[href='/app/sessions']" should exist

  # ---------------------------------------------------------------------------
  # Instruction Form
  # ---------------------------------------------------------------------------

  Scenario: Sessions page renders instruction form with textarea and Run button
    When I navigate to "${baseUrl}/app/sessions"
    And I wait for network idle
    Then "form#session-form" should exist
    And "textarea#session-instruction" should exist
    And I should see "Instruction"
    And I should see "Run"

  Scenario: Instruction textarea has placeholder text
    When I navigate to "${baseUrl}/app/sessions"
    And I wait for network idle
    Then "textarea#session-instruction[placeholder='Describe the coding task...']" should exist

  Scenario: Submitting empty instruction shows validation error
    When I navigate to "${baseUrl}/app/sessions"
    And I wait for network idle
    And I click the "Run" button
    And I wait for 1 seconds
    Then I should see "Instruction is required"

  # ---------------------------------------------------------------------------
  # Task History
  # ---------------------------------------------------------------------------

  Scenario: Task history shows seeded tasks
    When I navigate to "${baseUrl}/app/sessions"
    And I wait for network idle
    Then I should see "History"
    And I should see "Write unit tests for auth"
    And I should see "Refactor database queries"
    And I should see "Add API endpoint for users"

  Scenario: Task history table has expected column headers
    When I navigate to "${baseUrl}/app/sessions"
    And I wait for network idle
    Then I should see "Instruction"
    And I should see "Status"
    And I should see "Created"

  Scenario: Task history displays colour-coded status badges
    When I navigate to "${baseUrl}/app/sessions"
    And I wait for network idle
    Then I should see "completed"
    And I should see "failed"
    And I should see "cancelled"
    And "span.badge-success" should exist
    And "span.badge-error" should exist
    And "span.badge-ghost" should exist

  Scenario: Task history rows are clickable
    When I navigate to "${baseUrl}/app/sessions"
    And I wait for network idle
    Then "tr[phx-click='view_task']" should exist

  Scenario: Long instructions are truncated in history
    When I navigate to "${baseUrl}/app/sessions"
    And I wait for network idle
    # The seeded 156-char instruction is sliced at 80 chars + "..."
    Then I should see "This is a very long instruction that should be truncated in the task history tab"
    And I should not see "and this part should not be visible in the table row"
