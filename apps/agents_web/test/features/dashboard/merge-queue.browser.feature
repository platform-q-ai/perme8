@browser @dashboard @pipeline-kanban @merge-queue
Feature: Pipeline merge queue in the dashboard
  As a sessions dashboard user
  I want queued tickets to appear in the merge queue column
  So that I can see which work is waiting on final merge validation

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  Scenario: Merge queue tickets render in their own kanban column
    Given I navigate to "${baseUrl}/sessions?fixture=pipeline_kanban_merge_queue"
    And I wait for network idle
    Then "[data-testid='kanban-column-merge_queue']" should be visible
    And I should see "Merge Queue"
    And "[data-testid='kanban-column-merge_queue'] [data-testid='kanban-ticket-card-610']" should be visible
    And "[data-testid='kanban-column-ci_testing'] [data-testid='kanban-ticket-card-611']" should be visible
