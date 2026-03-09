@browser @sessions
Feature: Session Duration and File Change Stats on Sidebar Cards
  As a developer using the sessions page
  I want to see session duration and file change statistics on each sidebar card
  So that I can quickly assess how long sessions have been running and what code changes they have made without selecting each one

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle

  Scenario: Completed session card shows total duration
    And I wait for 1 seconds
    Then "[data-testid='session-item-completed-with-duration']" should exist
    And "[data-testid='session-item-completed-with-duration'] [data-testid='session-duration']" should exist
    And "[data-testid='session-item-completed-with-duration'] [data-testid='session-duration']" should contain text "5m"

  Scenario: Failed session card shows duration up to failure
    And I wait for 1 seconds
    Then "[data-testid='session-item-failed-with-duration']" should exist
    And "[data-testid='session-item-failed-with-duration'] [data-testid='session-duration']" should exist
    And "[data-testid='session-item-failed-with-duration'] [data-testid='session-duration']" should contain text "m"

  Scenario: Session card without started_at does not show duration
    And I wait for 1 seconds
    Then "[data-testid='session-item-pending-no-duration']" should exist
    And "[data-testid='session-item-pending-no-duration'] [data-testid='session-duration']" should not exist

  Scenario: Duration survives page reload for completed sessions
    And I wait for 1 seconds
    Then "[data-testid='session-item-completed-with-duration'] [data-testid='session-duration']" should contain text "5m"
    When I reload the page
    And I wait for network idle
    And I wait for 1 seconds
    Then "[data-testid='session-item-completed-with-duration'] [data-testid='session-duration']" should contain text "5m"

  @wip
  Scenario: Running session shows live-updating duration
    And I wait for 1 seconds
    Then "[data-testid='session-item-running'] [data-testid='session-duration']" should exist
    And "[data-testid='session-item-running'] [data-testid='session-duration']" should contain text "m"
    And I wait for 5 seconds

  Scenario: Completed session card shows file change stats
    And I wait for 1 seconds
    Then "[data-testid='session-item-completed-with-file-stats']" should exist
    And "[data-testid='session-item-completed-with-file-stats'] [data-testid='session-file-stats']" should exist
    And "[data-testid='session-item-completed-with-file-stats'] [data-testid='session-file-stats']" should contain text "3 files"
    And "[data-testid='session-item-completed-with-file-stats'] [data-testid='session-file-stats']" should contain text "+42"
    And "[data-testid='session-item-completed-with-file-stats'] [data-testid='session-file-stats']" should contain text "-18"

  Scenario: Session card without file stats does not show file change section
    And I wait for 1 seconds
    Then "[data-testid='session-item-no-file-stats']" should exist
    And "[data-testid='session-item-no-file-stats'] [data-testid='session-file-stats']" should not exist

  Scenario: File change stats survive page reload
    And I wait for 1 seconds
    Then "[data-testid='session-item-completed-with-file-stats'] [data-testid='session-file-stats']" should contain text "3 files"
    When I reload the page
    And I wait for network idle
    And I wait for 1 seconds
    Then "[data-testid='session-item-completed-with-file-stats'] [data-testid='session-file-stats']" should contain text "3 files"

  Scenario: Session card shows both duration and file stats together
    And I wait for 1 seconds
    Then "[data-testid='session-item-completed-with-duration'] [data-testid='session-duration']" should exist
    And "[data-testid='session-item-completed-with-file-stats'] [data-testid='session-file-stats']" should exist
