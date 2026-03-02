Feature: Build Queue Security
  As a security-conscious developer
  I want to ensure the build queue respects authorization boundaries
  So that users cannot manipulate other users' queues

  Scenario: Users can only view their own queue state
    Given I am logged in as user A
    And user A has 2 queued tasks
    And user B has 3 queued tasks
    When I view the queue panel
    Then I should only see user A's 2 queued tasks
    And I should not see user B's tasks

  Scenario: Users can only change their own concurrency limit
    Given I am logged in as user A
    When I change the concurrency limit to 3
    Then only user A's concurrency limit should be updated

  Scenario: Queue operations require authentication
    Given I am not logged in
    When I try to access the Sessions page
    Then I should be redirected to the login page

  Scenario: Queue position cannot be manipulated by the client
    Given I am logged in as a user
    And I have a queued task at position 3
    When I attempt to set the queue position to 1 via direct form manipulation
    Then the queue position should remain server-controlled
