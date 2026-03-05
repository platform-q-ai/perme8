@wip
Feature: Lightweight Container Image Selection and Queue Bypass
  As a developer using the sessions UI
  I want to select a lightweight discussion-only container image
  So that ticket triage and planning work starts instantly without consuming heavyweight build resources

  Background:
    Given I am logged in as a user with an active workspace

  Scenario: Light image appears in the image picker
    When I am composing a new session
    Then I should see the "OpenCode Light" image option in the image picker
    And I should also see the "OpenCode" and "Pi" image options

  Scenario: Selecting the light image updates the image picker
    When I am composing a new session
    And I select the "OpenCode Light" image
    Then the "OpenCode Light" option should be highlighted as active
    And the other image options should not be highlighted

  Scenario: Light image task bypasses the build queue when at concurrency limit
    Given the concurrency limit is 1
    And I have 1 running task using the "OpenCode" image
    When I create a new task with the "OpenCode Light" image
    Then the light image task should not have status "queued"
    And the light image task should start immediately

  Scenario: Light image task does not consume a concurrency slot
    Given the concurrency limit is 1
    And I have 1 running light image task
    When I create a new task with the "OpenCode" image
    Then the new task should start with status "pending"
    And the queue panel should not count the light image task against the concurrency limit

  Scenario: Multiple light image tasks can run simultaneously regardless of concurrency limit
    Given the concurrency limit is 1
    And I have 1 running light image task
    When I create another task with the "OpenCode Light" image
    Then both light image tasks should be running
    And neither should be queued

  Scenario: Light image label is shown on session card
    Given I have a running task using the "OpenCode Light" image
    When I navigate to the Sessions page
    Then the session card should display "OpenCode Light" as the image label

  Scenario: Light image task starts significantly faster than full image
    When I create a new task with the "OpenCode Light" image
    Then the task should reach "running" status faster than a typical "OpenCode" task
