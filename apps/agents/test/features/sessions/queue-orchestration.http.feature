@http
Feature: Queue orchestration engine and snapshot API
  As the queue orchestration system
  I want lane assignment, transitions, and snapshot generation to be rule-based
  So that queue behaviour is deterministic, testable, and the UI receives canonical snapshots

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"
    And I set bearer token to "${valid-user-token}"
    And I set header "X-Workspace-Id" to "${active-workspace-id}"

  Scenario: Running task is assigned to processing lane
    When I POST to "/internal/sessions/queue/lanes/assign" with body:
      """
      {
        "tasks": [
          {"task_id": "task-running-1", "status": "running"}
        ]
      }
      """
    Then the response status should be 200
    And the response body path "$.assignments[0].task_id" should equal "task-running-1"
    And the response body path "$.assignments[0].lane" should equal "processing"

  Scenario: Queued task with warm container is assigned to warm lane
    When I POST to "/internal/sessions/queue/lanes/assign" with body:
      """
      {
        "tasks": [
          {"task_id": "task-warm-1", "status": "queued", "container_state": "warm"}
        ]
      }
      """
    Then the response status should be 200
    And the response body path "$.assignments[0].lane" should equal "warm"

  Scenario: Queued task without container is assigned to cold lane
    When I POST to "/internal/sessions/queue/lanes/assign" with body:
      """
      {
        "tasks": [
          {"task_id": "task-cold-1", "status": "queued", "container_state": "none"}
        ]
      }
      """
    Then the response status should be 200
    And the response body path "$.assignments[0].lane" should equal "cold"

  Scenario: Task awaiting feedback is assigned to awaiting_feedback lane
    When I POST to "/internal/sessions/queue/lanes/assign" with body:
      """
      {
        "tasks": [
          {"task_id": "task-feedback-1", "status": "awaiting_feedback"}
        ]
      }
      """
    Then the response status should be 200
    And the response body path "$.assignments[0].lane" should equal "awaiting_feedback"

  Scenario: Queued task with retry count is assigned to retry_pending lane
    When I POST to "/internal/sessions/queue/lanes/assign" with body:
      """
      {
        "tasks": [
          {"task_id": "task-retry-1", "status": "queued", "retry_count": 2}
        ]
      }
      """
    Then the response status should be 200
    And the response body path "$.assignments[0].lane" should equal "retry_pending"

  Scenario: Completed task is not included in any lane
    When I POST to "/internal/sessions/queue/lanes/assign" with body:
      """
      {
        "tasks": [
          {"task_id": "task-completed-1", "status": "completed"}
        ]
      }
      """
    Then the response status should be 200
    And the response body path "$.assignments" should have 0 items

  Scenario: Queue snapshot includes all active lanes
    When I POST to "/internal/sessions/queue/snapshots" with body:
      """
      {
        "tasks": [
          {"task_id": "run-1", "status": "running"},
          {"task_id": "warm-1", "status": "queued", "container_state": "warm"},
          {"task_id": "cold-1", "status": "queued", "container_state": "none"},
          {"task_id": "cold-2", "status": "queued", "container_state": "none"},
          {"task_id": "feedback-1", "status": "awaiting_feedback"}
        ]
      }
      """
    Then the response status should be 200
    And the response body path "$.snapshot.lanes" should have 5 items
    And the response body path "$.snapshot.counts.processing" should equal 1
    And the response body path "$.snapshot.counts.warm" should equal 1
    And the response body path "$.snapshot.counts.cold" should equal 2
    And the response body path "$.snapshot.counts.awaiting_feedback" should equal 1

  Scenario: Queue snapshot includes metadata
    When I POST to "/internal/sessions/queue/snapshots" with body:
      """
      {
        "concurrency_limit": 3,
        "warm_cache_limit": 2,
        "tasks": [
          {"task_id": "run-meta-1", "status": "running"},
          {"task_id": "run-meta-2", "status": "running"}
        ]
      }
      """
    Then the response status should be 200
    And the response body path "$.snapshot.metadata.concurrency_limit" should equal 3
    And the response body path "$.snapshot.metadata.running_count" should equal 2
    And the response body path "$.snapshot.metadata.available_slots" should equal 1
    And the response body path "$.snapshot.metadata.warm_cache_limit" should equal 2

  Scenario: Task terminal status triggers promotion of next queued task
    When I POST to "/internal/sessions/queue/transitions/terminal" with body:
      """
      {
        "concurrency_limit": 1,
        "tasks": [
          {"task_id": "run-terminal-1", "status": "running"},
          {"task_id": "warm-next-1", "status": "queued", "container_state": "warm", "position": 1}
        ],
        "transition": {"task_id": "run-terminal-1", "to_status": "completed"}
      }
      """
    Then the response status should be 200
    And the response body path "$.promotions[0].task_id" should equal "warm-next-1"
    And the response body path "$.promotions[0].to_status" should equal "pending"
    And the response body path "$.snapshot_broadcasted" should be true

  Scenario: Warm tasks are promoted before cold tasks
    When I POST to "/internal/sessions/queue/promotions/run" with body:
      """
      {
        "tasks": [
          {"task_id": "warm-priority-1", "status": "queued", "container_state": "warm", "position": 2},
          {"task_id": "cold-priority-1", "status": "queued", "container_state": "none", "position": 1}
        ]
      }
      """
    Then the response status should be 200
    And the response body path "$.promotions[0].task_id" should equal "warm-priority-1"
    And the response body path "$.tasks[?(@.task_id=='cold-priority-1')].status[0]" should equal "queued"

  Scenario: Retryable failure schedules a retry
    When I POST to "/internal/sessions/queue/failures/handle" with body:
      """
      {
        "task": {
          "task_id": "retryable-1",
          "status": "failed",
          "retry_count": 0,
          "max_retries": 3,
          "error": "container_crashed"
        }
      }
      """
    Then the response status should be 200
    And the response body path "$.task.retry_count" should equal 1
    And the response body path "$.task.lane" should equal "retry_pending"
    And the response body path "$.events[0].name" should equal "TaskRetryScheduled"

  Scenario: Non-retryable failure does not schedule a retry
    When I POST to "/internal/sessions/queue/failures/handle" with body:
      """
      {
        "task": {
          "task_id": "non-retryable-1",
          "status": "failed",
          "retry_count": 0,
          "max_retries": 3,
          "error": "validation_error"
        }
      }
      """
    Then the response status should be 200
    And the response body path "$.task.status" should equal "failed"
    And the response body path "$.task.retry_scheduled" should be false

  Scenario: Retry-exhausted task is permanently failed
    When I POST to "/internal/sessions/queue/failures/handle" with body:
      """
      {
        "task": {
          "task_id": "retry-exhausted-1",
          "status": "failed",
          "retry_count": 3,
          "max_retries": 3,
          "error": "container_crashed"
        }
      }
      """
    Then the response status should be 200
    And the response body path "$.task.status" should equal "permanently_failed"
    And the response body path "$.task.error_code" should equal "retry_exhausted"

  Scenario: Setting concurrency limit within valid range succeeds
    When I PUT to "/internal/sessions/queue/config/concurrency" with body:
      """
      {"concurrency_limit": 5}
      """
    Then the response status should be 200
    And the response body path "$.metadata.concurrency_limit" should equal 5

  Scenario: Setting concurrency limit to 0 is rejected
    When I PUT to "/internal/sessions/queue/config/concurrency" with body:
      """
      {"concurrency_limit": 0}
      """
    Then the response status should be 422
    And the response body path "$.errors[0].code" should equal "validation_error"

  Scenario: Increasing concurrency limit triggers promotion
    When I POST to "/internal/sessions/queue/config/concurrency/increase" with body:
      """
      {
        "from": 1,
        "to": 2,
        "tasks": [
          {"task_id": "run-inc-1", "status": "running"},
          {"task_id": "warm-inc-1", "status": "queued", "container_state": "warm", "position": 1}
        ]
      }
      """
    Then the response status should be 200
    And the response body path "$.promotions[0].task_id" should equal "warm-inc-1"
    And the response body path "$.snapshot_broadcasted" should be true
