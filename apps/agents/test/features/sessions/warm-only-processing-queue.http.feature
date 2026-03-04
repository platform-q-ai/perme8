@wip
Feature: Warm-only queue promotion and warmup preparation
  As the sessions queue manager
  I want promotion to require warm readiness
  So processing starts only when containers are prepared

  Scenario: Promotion is blocked while queued tasks are cold
    Given user A has queued tasks
    And queued tasks are not yet warm-ready
    And processing capacity is available
    When queue promotion runs
    Then no queued task is promoted to pending
    And all tasks remain in queued status

  Scenario: Warm-ready queued task is promoted in queue order
    Given user A has queued tasks at positions 1 and 2
    And only position 2 is warm-ready
    When queue promotion runs
    Then position 1 remains queued
    And position 2 is not promoted ahead of position 1

  Scenario: Warmup marks top queued tasks warm-ready before promotion
    Given user A has queued tasks and warm target count of 2
    When warmup runs for top queued tasks
    Then top queued tasks are prepared until warm target is met
    And only prepared tasks become eligible for promotion
