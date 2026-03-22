@browser @sessions
Feature: Agent Session Todo Progress Bar
  As a developer watching an agent session
  I want to see a horizontal progress bar showing the agent's planned steps
  So that I can quickly gauge progress and hover to see details, saving screen space

  # Early-pipeline note:
  # These scenarios assume deterministic seeded sessions for each todo state
  # and stable test ids on session rows + todo progress UI.
  # LiveView patches arrive via WebSocket; a short wait after network idle
  # ensures the DOM has received the diff before assertions run.

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle

  # Browser todo-progress scenarios are temporarily disabled.
  # The progress UI remains covered by LiveView/component tests in
  # `apps/agents_web/test/live/dashboard/index_todo_test.exs` and
  # `apps/agents_web/test/live/dashboard/components/progress_bar_test.exs`.

  Scenario: Session card shows compact todo progress bar
    # Fixture session: has a todo list with completed and pending steps.
    # The session list card should show a compact progress bar.
    And I wait for 1 seconds
    Then "[data-testid='session-todo-progress']" should exist

  # Scenario: Progress bar updates active step during live execution — removed, requires live agent runtime (see #488)
  # Scenario: Progress bar resets when the agent replaces the todo list — removed, requires live agent runtime (see #488)
