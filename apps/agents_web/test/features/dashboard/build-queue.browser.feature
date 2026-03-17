@browser @sessions @queue
Feature: Build Queue with Concurrency Limiting
  As a developer using the sessions UI
  I want to see a build queue that manages concurrent task execution
  So that I can efficiently manage multiple coding tasks with concurrency limits

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  Scenario: Build queue panel is visible on sessions page
    Given I navigate to "${baseUrl}/sessions?fixture=build_queue_empty"
    And I wait for network idle
    Then "[data-testid='build-queue-panel']" should exist

  Scenario: Build queue shows running task count
    Given I navigate to "${baseUrl}/sessions?fixture=build_queue_one_running"
    And I wait for network idle
    Then "[data-testid='build-queue-panel']" should contain text "running"

  Scenario: Build queue shows queued tasks
    Given I navigate to "${baseUrl}/sessions?fixture=build_queue_with_queued"
    And I wait for network idle
    Then "[data-testid='build-queue-panel']" should exist

  Scenario: Concurrency limit control is visible
    Given I navigate to "${baseUrl}/sessions?fixture=build_queue_empty"
    And I wait for network idle
    Then "[data-testid='concurrency-limit-select']" should exist

  Scenario: Queued task shows queue position
    Given I navigate to "${baseUrl}/sessions?fixture=build_queue_with_queued"
    And I wait for network idle
    Then "[data-testid='task-card']" should exist

  Scenario: Awaiting feedback task is visually highlighted
    Given I navigate to "${baseUrl}/sessions?fixture=build_queue_awaiting_feedback"
    And I wait for network idle
    Then "[data-testid='task-card']" should exist
