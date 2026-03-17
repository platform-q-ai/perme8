@browser
Feature: Queue orchestration with rule-based lanes and reactive UI
  As a developer using the sessions UI
  I want to see a build queue that organizes tasks into explicit lanes
  So that queue behavior is deterministic and understandable at a glance

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  Scenario: Queue panel displays lanes in bottom-up order
    Given I navigate to "${baseUrl}/sessions?fixture=queue_lanes_order"
    And I wait for network idle
    Then "[data-testid='build-queue-panel']" should be visible
    And "[data-testid='queue-lanes'] [data-testid='queue-lane']:last-child" should contain text "Processing"
    And "[data-testid='queue-lanes'] [data-testid='queue-lane']:nth-last-child(2)" should contain text "Warm"
    And "[data-testid='queue-lanes'] [data-testid='queue-lane']:nth-last-child(3)" should contain text "Cold"

  Scenario: Processing lane shows actively running tasks
    Given I navigate to "${baseUrl}/sessions?fixture=queue_processing_two_running"
    And I wait for network idle
    Then there should be 2 "[data-testid='lane-processing'] [data-testid='task-card']" elements
    And there should be 2 "[data-testid='lane-processing'] [data-testid='task-running-indicator']" elements

  Scenario: Warm lane shows queued tasks with pre-warmed containers
    Given I navigate to "${baseUrl}/sessions?fixture=queue_warm_one_task"
    And I wait for network idle
    Then there should be 1 "[data-testid='lane-warm'] [data-testid='task-card']" elements
    And "[data-testid='lane-warm'] [data-testid='task-card']:first-child" should contain text "Warm"

  Scenario: Cold lane shows queued tasks without containers
    Given I navigate to "${baseUrl}/sessions?fixture=queue_cold_two_tasks"
    And I wait for network idle
    Then there should be 2 "[data-testid='lane-cold'] [data-testid='task-card']" elements
    And there should be 2 "[data-testid='lane-cold'] [data-testid='task-cold-indicator']" elements

  Scenario: Awaiting feedback lane shows tasks blocked on user input
    Given I navigate to "${baseUrl}/sessions?fixture=queue_awaiting_feedback"
    And I wait for network idle
    Then there should be 1 "[data-testid='lane-awaiting-feedback'] [data-testid='task-card']" elements
    And "[data-testid='lane-awaiting-feedback'] [data-testid='task-card']:first-child" should have class "needs-attention"

  Scenario: Retry pending lane shows tasks waiting to retry
    Given I navigate to "${baseUrl}/sessions?fixture=queue_retry_pending"
    And I wait for network idle
    Then there should be 1 "[data-testid='lane-retry-pending'] [data-testid='task-card']" elements
    And "[data-testid='lane-retry-pending'] [data-testid='task-card']:first-child" should contain text "1/3"
    And "[data-testid='lane-retry-pending'] [data-testid='task-card']:first-child" should contain text "Next retry"

  Scenario: Queue panel shows concurrency metadata from snapshot
    Given I navigate to "${baseUrl}/sessions?fixture=queue_concurrency_two_of_three"
    And I wait for network idle
    Then "[data-testid='build-queue-panel']" should contain text "2/3 running"
    And "[data-testid='build-queue-panel']" should contain text "1 slot available"

  Scenario: Queue panel shows warm cache metadata from snapshot
    Given I navigate to "${baseUrl}/sessions?fixture=queue_warm_cache_one_of_two"
    And I wait for network idle
    Then "[data-testid='build-queue-panel']" should contain text "Warm cache"
    And "[data-testid='build-queue-panel']" should contain text "1/2"

  Scenario: Completing a running task promotes the next warm queued task
    Given I navigate to "${baseUrl}/sessions?fixture=queue_promotion_warm_then_cold"
    And I wait for network idle
    When I click "[data-testid='lane-processing'] [data-testid='task-card']:first-child [data-testid='complete-task']"
    And I wait for network idle
    Then "[data-testid='lane-processing'] [data-testid='task-card']:first-child" should contain text "Warm"
    And there should be 1 "[data-testid='lane-cold'] [data-testid='task-card']" elements

  Scenario: Warm tasks are promoted before cold tasks
    Given I navigate to "${baseUrl}/sessions?fixture=queue_promotion_prioritize_warm"
    And I wait for network idle
    When I click the "Run Queue Promotion" button
    And I wait for network idle
    Then "[data-testid='lane-processing'] [data-testid='task-card']:first-child" should contain text "Warm"
    And "[data-testid='lane-cold'] [data-testid='task-card']:first-child" should contain text "Cold"

  Scenario: Failed task with retryable error moves to retry pending lane
    Given I navigate to "${baseUrl}/sessions?fixture=queue_retryable_failure"
    And I wait for network idle
    When I click "[data-testid='lane-processing'] [data-testid='task-card']:first-child [data-testid='fail-retryable']"
    And I wait for network idle
    Then there should be 1 "[data-testid='lane-retry-pending'] [data-testid='task-card']" elements
    And "[data-testid='lane-retry-pending'] [data-testid='task-card']:first-child" should contain text "1/3"

  Scenario: Retry pending task is re-queued after backoff period
    Given I navigate to "${baseUrl}/sessions?fixture=queue_retry_pending_backoff"
    And I wait for network idle
    When I click the "Advance Backoff Timer" button
    And I wait for network idle
    Then there should be 1 "[data-testid='lane-cold'] [data-testid='task-card']" elements
    And "[data-testid='lane-cold'] [data-testid='task-card']:first-child" should contain text "Eligible"

  Scenario: Task exhausting retries moves to terminal state
    Given I navigate to "${baseUrl}/sessions?fixture=queue_retries_exhausted"
    And I wait for network idle
    When I click "[data-testid='lane-processing'] [data-testid='task-card']:first-child [data-testid='fail-retryable']"
    And I wait for network idle
    Then there should be 0 "[data-testid='queue-lanes'] [data-testid='task-card'][data-task-id='exhausted-task']" elements
    And I should see "Permanently failed"

  Scenario: Increasing concurrency limit promotes queued tasks
    Given I navigate to "${baseUrl}/sessions?fixture=queue_increase_concurrency"
    And I wait for network idle
    When I select "2" from "[data-testid='concurrency-limit-select']"
    And I wait for network idle
    Then "[data-testid='lane-processing'] [data-testid='task-card']:last-child" should contain text "Warm"

  Scenario: Decreasing concurrency limit does not stop running tasks
    Given I navigate to "${baseUrl}/sessions?fixture=queue_decrease_concurrency"
    And I wait for network idle
    When I select "1" from "[data-testid='concurrency-limit-select']"
    And I wait for network idle
    Then there should be 3 "[data-testid='lane-processing'] [data-testid='task-card']" elements
    And "[data-testid='build-queue-panel']" should contain text "No promotions until running drops below 1"
