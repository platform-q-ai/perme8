@browser @sessions
Feature: Agent Session Todo Progress Bar
  As a developer watching an agent session
  I want to see a numbered progress bar showing the agent's planned steps
  So that I understand what the agent intends to do and can track progress

  # Early-pipeline note:
  # These scenarios assume deterministic seeded sessions for each todo state
  # and stable test ids on session rows + todo progress UI.

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle

  Scenario: Progress bar appears when a session has a todo list
    # Fixture session: has a todo list with planned steps.
    When I click "[data-testid='session-item-todo-initial']"
    And I wait for network idle
    Then "[data-testid='todo-progress']" should exist
    And "[data-testid='todo-progress-summary']" should contain text "steps complete"
    And there should be 4 "[data-testid^='todo-step-']" elements

  Scenario: Progress bar shows numbered step names
    # Fixture session: same todo list as initial state.
    When I click "[data-testid='session-item-todo-initial']"
    And I wait for network idle
    Then "[data-testid='todo-step-1']" should contain text "1."
    And "[data-testid='todo-step-1']" should contain text "Plan"
    And "[data-testid='todo-step-2']" should contain text "2."
    And "[data-testid='todo-step-2']" should contain text "Implement"

  Scenario: Progress bar shows completed steps and correct summary count
    # Fixture session: 3 of 7 todo steps are completed.
    When I click "[data-testid='session-item-todo-3-of-7-complete']"
    And I wait for network idle
    Then "[data-testid='todo-progress-summary']" should have text "3/7 steps complete"
    And "[data-testid='todo-step-1']" should have class "is-completed"
    And "[data-testid='todo-step-2']" should have class "is-completed"
    And "[data-testid='todo-step-3']" should have class "is-completed"

  Scenario: Progress bar shows failed steps without changing other statuses
    # Fixture session: one step failed, others preserve their own states.
    When I click "[data-testid='session-item-todo-with-failed-step']"
    And I wait for network idle
    Then "[data-testid='todo-step-3']" should have class "is-failed"
    And "[data-testid='todo-step-1']" should have class "is-completed"
    And "[data-testid='todo-step-2']" should have class "is-in-progress"
    And "[data-testid='todo-step-4']" should have class "is-pending"

  Scenario: Progress bar is hidden when no todo list exists
    # Fixture session: active session output exists but no todo list was created.
    When I click "[data-testid='session-item-no-todo']"
    And I wait for network idle
    Then "[data-testid='todo-progress']" should not exist
    And "#session-log" should exist

  Scenario: Progress bar state persists after page reload
    # Fixture session: mixed todo states with a visible progress summary.
    When I click "[data-testid='session-item-todo-3-of-7-complete']"
    And I wait for network idle
    And I store the text of "[data-testid='todo-progress-summary']" as "summaryBeforeReload"
    And I reload the page
    And I wait for network idle
    Then "[data-testid='todo-progress-summary']" should have text "${summaryBeforeReload}"
    And "[data-testid='todo-step-1']" should have class "is-completed"
    And "[data-testid='todo-step-4']" should have class "is-pending"

  Scenario: Completed session shows final todo state
    # Fixture session: completed agent session with final todo outcomes.
    When I click "[data-testid='session-item-todo-session-completed']"
    And I wait for network idle
    Then "[data-testid='todo-progress']" should exist
    And "[data-testid='todo-progress-summary']" should contain text "steps complete"
    And I should not see "Working..."

  @wip
  Scenario: Progress bar updates active step during live execution
    # Requires live agent runtime and real-time PubSub transitions; cannot be
    # reliably triggered from static browser fixtures in early-pipeline mode.
    When I click "[data-testid='session-item-live-todo-run']"
    And I wait for network idle
    Then "[data-testid='todo-step-2']" should have class "is-in-progress"
    And "[data-testid='todo-progress-summary']" should contain text "steps complete"

  @wip
  Scenario: Progress bar resets when the agent replaces the todo list
    # Requires live agent interaction to replace one todo list with another in
    # the same session; static seeded state cannot verify replacement behavior.
    When I click "[data-testid='session-item-live-todo-replaced']"
    And I wait for network idle
    Then there should be 3 "[data-testid^='todo-step-']" elements
    And "[data-testid='todo-progress-summary']" should have text "0/3 steps complete"
