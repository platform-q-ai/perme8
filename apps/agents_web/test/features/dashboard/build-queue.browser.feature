Feature: Build Queue with Concurrency Limiting
  As a developer using the sessions UI
  I want to see a build queue that manages concurrent task execution
  So that I can efficiently manage multiple coding tasks with concurrency limits

  Background:
    Given I am logged in as a user with an active workspace

  # Queue Panel Display

  Scenario: Queue panel is visible on the Sessions page
    When I navigate to the Sessions page
    Then I should see the "Build Queue" panel
    And the queue panel should display the concurrency limit control
    And the queue panel should show "0/2 running"

  Scenario: Queue panel shows running task count
    Given I have 1 running task
    When I navigate to the Sessions page
    Then the queue panel should show "1/2 running"

  Scenario: Queue panel shows queued tasks
    Given I have 2 running tasks
    And I have 1 queued task at position 1
    When I navigate to the Sessions page
    Then the queue panel should show "2/2 running"
    And the queue panel should show "1 queued"
    And I should see the queued task with its queue position

  Scenario: Queue panel shows awaiting feedback tasks
    Given I have 1 task awaiting feedback
    When I navigate to the Sessions page
    Then the queue panel should show "1 awaiting feedback"
    And the awaiting feedback task should be visually highlighted

  # Concurrency Limit Control

  Scenario: Changing the concurrency limit
    When I navigate to the Sessions page
    And I change the concurrency limit to 3
    Then the queue panel should show the new limit of 3

  Scenario: Increasing concurrency limit promotes queued tasks
    Given I have 1 running task
    And I have 1 queued task at position 1
    And the concurrency limit is 1
    When I change the concurrency limit to 2
    Then the queued task should be promoted to pending

  # Task Creation and Queuing

  Scenario: Creating a task when below concurrency limit starts it immediately
    Given the concurrency limit is 2
    And I have 0 running tasks
    When I create a new task with instruction "Write tests"
    Then the task should start with status "pending"
    And the task should not be queued

  Scenario: Creating a task when at concurrency limit queues it
    Given the concurrency limit is 1
    And I have 1 running task
    When I create a new task with instruction "Write more tests"
    Then the new task should have status "queued"
    And the new task should have a queue position

  # Task Promotion

  Scenario: Completing a task promotes the next queued task
    Given I have 1 running task
    And I have 2 queued tasks
    And the concurrency limit is 1
    When the running task completes
    Then the first queued task should be promoted to pending
    And the second queued task should remain queued

  Scenario: Failing a task promotes the next queued task
    Given I have 1 running task
    And I have 1 queued task
    And the concurrency limit is 1
    When the running task fails
    Then the queued task should be promoted to pending

  Scenario: Cancelling a task promotes the next queued task
    Given I have 1 running task
    And I have 1 queued task
    And the concurrency limit is 1
    When I cancel the running task
    Then the queued task should be promoted to pending

  # Status Badges

  Scenario: Queued status is displayed with correct badge
    Given I have a task with status "queued"
    When I navigate to the Sessions page
    Then I should see a "queued" status badge

  Scenario: Awaiting feedback status is displayed with correct badge
    Given I have a task with status "awaiting_feedback"
    When I navigate to the Sessions page
    Then I should see an "awaiting feedback" status badge with pulse animation
