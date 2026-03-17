Feature: Warm-only processing queue controls in Sessions UI
  As a user managing agent sessions
  I want to configure fresh warm-container capacity
  So the queue can keep ready containers without promoting cold tasks

  Background:
    Given I am logged in as a user with an active workspace

  Scenario: Session list shows fresh warm-container target selector
    When I navigate to the Sessions page
    Then I should see a control for fresh warm-container count
    And the control should display my current fresh warm target

  Scenario: Updating fresh warm-container target applies to queue warming behavior
    Given I have queued tasks in the session list
    When I set fresh warm-container target count to 3
    Then the selected fresh warm-container target should be saved
    And queue warming should use a target count of 3

  Scenario: Queued tasks stay queued until warm-ready
    Given I have queued tasks and available processing capacity
    And no queued task is warm-ready
    When queue promotion is evaluated
    Then queued tasks should remain queued
    And no queued task should enter processing/running
