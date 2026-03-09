@browser @sessions @lifecycle
Feature: Session lifecycle state display in Sessions UI
  As a user viewing my session list
  I want to see whether my task is cold-queued, warming up, or actively running
  So that I understand what the system is doing and how long I might wait

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  Scenario: Unauthenticated user is redirected to login before viewing lifecycle states
    Given I open browser session "anonymous"
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then the URL should contain "/users/log-in"
    And I should see "Log in"

  Scenario: User can log in and access the Sessions page
    Given I open browser session "fresh-login"
    And I navigate to "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    Then the URL should contain "/sessions"
    And "[data-testid='session-list']" should exist

  Scenario: Login with invalid credentials shows an error
    Given I open browser session "failed-login"
    And I navigate to "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "wrong@example.com"
    And I fill "#login_form_password_password" with "wrongpassword"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    Then the URL should contain "/users/log-in"
    And I should see "Invalid email or password"

  Scenario: Cold-queued task shows correct lifecycle state
    Given I navigate to "${baseUrl}/sessions?fixture=session_lifecycle_queued_cold"
    And I wait for network idle
    Then "[data-testid='session-task-card']:first-child [data-testid='lifecycle-state']" should have text "Queued (cold)"

  Scenario: Warm-queued task shows correct lifecycle state
    Given I navigate to "${baseUrl}/sessions?fixture=session_lifecycle_queued_warm"
    And I wait for network idle
    Then "[data-testid='session-task-card']:first-child [data-testid='lifecycle-state']" should have text "Queued (warm)"

  Scenario: Warming task shows correct lifecycle state
    Given I navigate to "${baseUrl}/sessions?fixture=session_lifecycle_warming"
    And I wait for network idle
    Then "[data-testid='session-task-card']:first-child [data-testid='lifecycle-state']" should have text "Warming up"

  Scenario: Starting task shows correct lifecycle state
    Given I navigate to "${baseUrl}/sessions?fixture=session_lifecycle_starting"
    And I wait for network idle
    Then "[data-testid='session-task-card']:first-child [data-testid='lifecycle-state']" should have text "Starting"

  Scenario: Running task shows correct lifecycle state
    Given I navigate to "${baseUrl}/sessions?fixture=session_lifecycle_running"
    And I wait for network idle
    Then "[data-testid='session-task-card']:first-child [data-testid='lifecycle-state']" should have text "Running"

  Scenario: Awaiting feedback task shows correct lifecycle state
    Given I navigate to "${baseUrl}/sessions?fixture=session_lifecycle_awaiting_feedback"
    And I wait for network idle
    Then "[data-testid='session-task-card']:first-child [data-testid='lifecycle-state']" should have text "Awaiting feedback"

  Scenario: Completed task shows correct lifecycle state
    Given I navigate to "${baseUrl}/sessions?fixture=session_lifecycle_completed"
    And I wait for network idle
    Then "[data-testid='session-task-card']:first-child [data-testid='lifecycle-state']" should have text "Completed"

  Scenario: Failed task shows correct lifecycle state
    Given I navigate to "${baseUrl}/sessions?fixture=session_lifecycle_failed"
    And I wait for network idle
    Then "[data-testid='session-task-card']:first-child [data-testid='lifecycle-state']" should have text "Failed"

  Scenario: Cancelled task shows correct lifecycle state
    Given I navigate to "${baseUrl}/sessions?fixture=session_lifecycle_cancelled"
    And I wait for network idle
    Then "[data-testid='session-task-card']:first-child [data-testid='lifecycle-state']" should have text "Cancelled"

  Scenario: Real-time transition from cold-queued to warming
    Given I navigate to "${baseUrl}/sessions?fixture=session_lifecycle_transition_cold_to_warming"
    And I wait for network idle
    When I click "[data-testid='simulate-transition-cold-to-warming']"
    And I wait for network idle
    Then "[data-testid='session-task-card'][data-task-id='transition-task'] [data-testid='lifecycle-state']" should have text "Warming up"

  Scenario: Real-time transition from warming to starting to running
    Given I navigate to "${baseUrl}/sessions?fixture=session_lifecycle_transition_warming_to_running"
    And I wait for network idle
    When I click "[data-testid='simulate-transition-warming-to-starting']"
    And I wait for network idle
    Then "[data-testid='session-task-card'][data-task-id='transition-task'] [data-testid='lifecycle-state']" should have text "Starting"
    When I click "[data-testid='simulate-transition-starting-to-running']"
    And I wait for network idle
    Then "[data-testid='session-task-card'][data-task-id='transition-task'] [data-testid='lifecycle-state']" should have text "Running"

  Scenario: Warm-queued task transitions faster than cold-queued
    Given I navigate to "${baseUrl}/sessions?fixture=session_lifecycle_transition_warm_fast_path"
    And I wait for network idle
    When I click "[data-testid='promote-warm-task']"
    And I wait for network idle
    Then "[data-testid='session-task-card'][data-task-id='warm-fast-task'] [data-testid='lifecycle-state-warming']" should not exist
    And "[data-testid='session-task-card'][data-task-id='warm-fast-task'] [data-testid='lifecycle-state']" should contain text "Running"

  Scenario: Session state machine includes warm-state predicates
    Given I navigate to "${baseUrl}/sessions?fixture=session_lifecycle_state_machine_warming"
    And I wait for network idle
    Then "[data-testid='session-task-card'][data-task-id='warming-task'] [data-testid='lifecycle-state']" should have text "Warming up"
    And "[data-testid='session-task-card'][data-task-id='warming-task'] [data-testid='state-predicate-active']" should be visible
    And "[data-testid='session-task-card'][data-task-id='warming-task'] [data-testid='state-predicate-terminal']" should not exist

  Scenario: Ticket entity carries full lifecycle state instead of lossy mapping
    Given I navigate to "${baseUrl}/sessions?fixture=session_lifecycle_ticket_queued_cold"
    And I wait for network idle
    Then "[data-testid='triage-ticket-item']:first-child [data-testid='ticket-lifecycle-state']" should have text "Queued (cold)"
    And "[data-testid='triage-ticket-item']:first-child [data-testid='ticket-status-running']" should not exist

  Scenario: Queue lane shows lifecycle-aware warm state indicator
    Given I navigate to "${baseUrl}/sessions?fixture=session_lifecycle_queue_indicators"
    And I wait for network idle
    Then "[data-testid='lane-cold'] [data-testid='warm-state-indicator-cold']" should exist
    And "[data-testid='lane-warming'] [data-testid='warm-state-indicator-warming']" should exist
    And "[data-testid='lane-warm'] [data-testid='warm-state-indicator-warm']" should exist
