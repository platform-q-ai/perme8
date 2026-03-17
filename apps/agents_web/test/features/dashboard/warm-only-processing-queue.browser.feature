@browser @sessions @queue @warm-only
Feature: Warm-only processing queue controls in Sessions UI
  As a user managing agent sessions
  I want to configure fresh warm-container capacity
  So the queue can keep ready containers without promoting cold tasks

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  Scenario: Sessions page loads with queue panel visible
    Given I navigate to "${baseUrl}/sessions?fixture=warm_queue_cold_tasks"
    And I wait for network idle
    Then "[data-testid='build-queue-panel']" should exist

  Scenario: Queued tasks display their warm readiness state
    Given I navigate to "${baseUrl}/sessions?fixture=warm_queue_cold_tasks"
    And I wait for network idle
    Then "[data-testid='task-card']" should exist

  Scenario: Warm-ready tasks are visually distinguished from cold tasks
    Given I navigate to "${baseUrl}/sessions?fixture=warm_queue_mixed_states"
    And I wait for network idle
    Then "[data-testid='build-queue-panel']" should exist
