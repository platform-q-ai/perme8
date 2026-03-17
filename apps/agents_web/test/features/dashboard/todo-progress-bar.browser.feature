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

  Scenario: Horizontal progress bar appears when a session has a todo list
    # Fixture session: has a todo list with planned steps.
    When I click "[data-testid='session-item-todo-initial']"
    And I wait for network idle
    And I wait for 1 seconds
    Then "[data-testid='todo-progress']" should exist
    And "[data-testid='todo-progress-summary']" should contain text "steps complete"
    And there should be 4 "[data-testid^='todo-step-']" elements

  Scenario: Step details are shown in tooltip on hover
    # Fixture session: same todo list as initial state.
    # The horizontal segments contain tooltip text in the DOM.
    When I click "[data-testid='session-item-todo-initial']"
    And I wait for network idle
    And I wait for 1 seconds
    Then "[data-testid='todo-step-1']" should contain text "1."
    And "[data-testid='todo-step-1']" should contain text "Plan"
    And "[data-testid='todo-step-2']" should contain text "2."
    And "[data-testid='todo-step-2']" should contain text "Implement"

  Scenario: Progress bar shows completed steps and correct summary count
    # Fixture session: 3 of 7 todo steps are completed.
    When I click "[data-testid='session-item-todo-3-of-7-complete']"
    And I wait for network idle
    And I wait for 1 seconds
    Then "[data-testid='todo-progress-summary']" should have text "3/7 steps complete"
    And "[data-testid='todo-step-1']" should have class "is-completed"
    And "[data-testid='todo-step-2']" should have class "is-completed"
    And "[data-testid='todo-step-3']" should have class "is-completed"

  Scenario: Progress bar shows failed steps without changing other statuses
    # Fixture session: one step failed, others preserve their own states.
    When I click "[data-testid='session-item-todo-with-failed-step']"
    And I wait for network idle
    And I wait for 1 seconds
    Then "[data-testid='todo-step-3']" should have class "is-failed"
    And "[data-testid='todo-step-1']" should have class "is-completed"
    And "[data-testid='todo-step-2']" should have class "is-in-progress"
    And "[data-testid='todo-step-4']" should have class "is-pending"

  Scenario: Progress bar is hidden when no todo list exists
    # Fixture session: active session output exists but no todo list was created.
    When I click "[data-testid='session-item-no-todo']"
    And I wait for network idle
    And I wait for 1 seconds
    Then "[data-testid='todo-progress']" should not exist
    And "#session-log" should exist

  Scenario: Progress bar state persists after page reload
    # Fixture session: mixed todo states with a visible progress summary.
    When I click "[data-testid='session-item-todo-3-of-7-complete']"
    And I wait for network idle
    And I wait for 1 seconds
    Then "[data-testid='todo-progress-summary']" should contain text "3/7 steps complete"
    When I reload the page
    And I wait for network idle
    # Re-select the session after reload since mount auto-selects the first session
    When I click "[data-testid='session-item-todo-3-of-7-complete']"
    And I wait for network idle
    And I wait for 1 seconds
    Then "[data-testid='todo-progress-summary']" should contain text "3/7 steps complete"
    And "[data-testid='todo-step-1']" should have class "is-completed"
    And "[data-testid='todo-step-4']" should have class "is-pending"

  Scenario: Completed session shows final todo state
    # Fixture session: completed agent session with final todo outcomes.
    When I click "[data-testid='session-item-todo-session-completed']"
    And I wait for network idle
    And I wait for 1 seconds
    Then "[data-testid='todo-progress']" should exist
    And "[data-testid='todo-progress-summary']" should contain text "steps complete"
    And I should not see "Working..."

  Scenario: Session card shows compact todo progress bar
    # Fixture session: has a todo list with completed and pending steps.
    # The session list card should show a compact progress bar.
    And I wait for 1 seconds
    Then "[data-testid='session-todo-progress']" should exist

  # Scenario: Progress bar updates active step during live execution — removed, requires live agent runtime (see ticket)
  # Scenario: Progress bar resets when the agent replaces the todo list — removed, requires live agent runtime (see ticket)
