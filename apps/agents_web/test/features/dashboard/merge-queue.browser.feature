@browser @dashboard @pipeline-kanban @merge-queue
Feature: Pipeline Phase 8 - Merge Queue
  As a maintainer using the sessions dashboard
  I want eligible pull requests to enter a merge queue and pass pre-merge validation before merging
  So that changes land on main only after queue ordering and merge-result validation succeed

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  Scenario: Unauthenticated user is redirected to login before viewing the merge queue dashboard
    Given I open browser session "anonymous"
    And I navigate to "${baseUrl}/sessions?fixture=pipeline_merge_queue_column"
    And I wait for network idle
    Then the URL should contain "/users/log-in"
    And I should see "Log in"

  Scenario: Login with invalid credentials shows an error
    Given I open browser session "failed-login"
    And I navigate to "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "wrong@example.com"
    And I fill "#login_form_password_password" with "wrongpassword"
    And I click the "Log in and stay logged in" button
    And I wait for network idle
    Then the URL should contain "/users/log-in"
    And I should see "Invalid email or password"

  Scenario: Merge queue column appears in the pipeline kanban
    Given I navigate to "${baseUrl}/sessions?fixture=pipeline_merge_queue_column"
    And I wait for network idle
    Then I should see "Pipeline"
    And I should see "Merge Queue"
    And I should see "#610 in Merge Queue"

  Scenario: Eligible work appears in the merge queue
    Given I navigate to "${baseUrl}/sessions?fixture=pipeline_merge_queue_eligible"
    And I wait for network idle
    Then I should see "Merge Queue"
    And I should see "#611 in Merge Queue"
    And I should not see "#611 in CI Testing"

  Scenario: Ineligible work stays out of the merge queue
    Given I navigate to "${baseUrl}/sessions?fixture=pipeline_merge_queue_ineligible"
    And I wait for network idle
    Then I should see "Merge Queue"
    And I should not see "#612 in Merge Queue"
    And I should see "#612 in CI Testing"

  Scenario: Validation failure keeps queued work from merging
    Given I navigate to "${baseUrl}/sessions?fixture=pipeline_merge_queue_validation_failed"
    And I wait for network idle
    When I reload the page
    And I wait for network idle
    Then I should see "#613 in Merge Queue"
    And I should see "Merge validation failed"
    And I should see "Blocked from merge"
