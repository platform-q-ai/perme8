@browser @dashboard @lifecycle-tracking
Feature: Ticket lifecycle time tracking in Sessions UI
  As a dashboard user managing tickets and agent sessions
  I want to see how long a ticket has been in its current lifecycle stage
  And see the total time spent at each lifecycle stage
  So that I can identify bottlenecks and understand the development pipeline

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  Scenario: Unauthenticated user is redirected to login before viewing ticket lifecycle tracking
    Given I open browser session "anonymous"
    And I navigate to "${baseUrl}/sessions"
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

  Scenario: Ticket card displays current lifecycle stage badge
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_lifecycle_in_progress"
    And I wait for network idle
    Then "[data-testid='triage-ticket-item'][data-ticket-id='in-progress-ticket'] [data-testid='ticket-lifecycle-stage']" should have text "In Progress"

  Scenario: Ticket card displays duration in current stage
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_lifecycle_in_progress_duration"
    And I wait for network idle
    Then "[data-testid='triage-ticket-item'][data-ticket-id='in-progress-duration-ticket'] [data-testid='ticket-lifecycle-duration']" should contain text "2h"

  Scenario: Ticket card shows lifecycle stage for each stage type
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_lifecycle_all_stages"
    And I wait for network idle
    Then "[data-testid='triage-ticket-item'][data-lifecycle-stage='open'] [data-testid='ticket-lifecycle-stage']" should have text "Open"
    And "[data-testid='triage-ticket-item'][data-lifecycle-stage='ready'] [data-testid='ticket-lifecycle-stage']" should have text "Ready"
    And "[data-testid='triage-ticket-item'][data-lifecycle-stage='in_progress'] [data-testid='ticket-lifecycle-stage']" should have text "In Progress"
    And "[data-testid='triage-ticket-item'][data-lifecycle-stage='in_review'] [data-testid='ticket-lifecycle-stage']" should have text "In Review"
    And "[data-testid='triage-ticket-item'][data-lifecycle-stage='ci_testing'] [data-testid='ticket-lifecycle-stage']" should have text "CI Testing"
    And "[data-testid='triage-ticket-item'][data-lifecycle-stage='deployed'] [data-testid='ticket-lifecycle-stage']" should have text "Deployed"
    And "[data-testid='triage-ticket-item'][data-lifecycle-stage='closed'] [data-testid='ticket-lifecycle-stage']" should have text "Closed"

  Scenario: Ticket detail tab shows lifecycle timeline
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_lifecycle_timeline&new=true&tab=ticket&ticket=430"
    And I wait for network idle
    Then "[data-testid='ticket-lifecycle-timeline']" should be visible
    And there should be 3 "[data-testid='ticket-lifecycle-timeline-stage']" elements
    And "[data-testid='ticket-lifecycle-timeline-stage-duration']" should exist

  Scenario: Lifecycle timeline shows relative duration bars
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_lifecycle_relative_durations&new=true&tab=ticket&ticket=431"
    And I wait for network idle
    Then "[data-testid='ticket-lifecycle-timeline']" should be visible
    And there should be 3 "[data-testid='ticket-lifecycle-duration-bar']" elements
    And "[data-testid='ticket-lifecycle-duration-bar'][data-stage='open']" should have attribute "data-relative-width" with value "10"
    And "[data-testid='ticket-lifecycle-duration-bar'][data-stage='ready']" should have attribute "data-relative-width" with value "30"
    And "[data-testid='ticket-lifecycle-duration-bar'][data-stage='in_progress']" should have attribute "data-relative-width" with value "60"

  Scenario: Ticket card displays lifecycle stage and duration together
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_lifecycle_realtime_transition"
    And I wait for network idle
    Then "[data-testid='triage-ticket-item'][data-ticket-id='ticket-402'] [data-testid='ticket-lifecycle-stage']" should have text "In Progress"
    And "[data-testid='triage-ticket-item'][data-ticket-id='ticket-402'] [data-testid='ticket-lifecycle-duration']" should contain text "2h"

  Scenario: Newly synced ticket shows initial lifecycle stage
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_lifecycle_newly_synced"
    And I wait for network idle
    Then "[data-testid='triage-ticket-item'][data-ticket-id='newly-synced-ticket'] [data-testid='ticket-lifecycle-stage']" should have text "Open"
    And "[data-testid='triage-ticket-item'][data-ticket-id='newly-synced-ticket'] [data-testid='ticket-lifecycle-duration']" should exist

  Scenario: Closed ticket shows final lifecycle stage
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_lifecycle_closed"
    And I wait for network idle
    Then "[data-testid='triage-ticket-item'][data-ticket-id='closed-ticket'] [data-testid='ticket-lifecycle-stage']" should have text "Closed"
    And "[data-testid='triage-ticket-item'][data-ticket-id='closed-ticket'] [data-testid='ticket-lifecycle-duration']" should exist

  Scenario: Ticket with no lifecycle events shows default state
    Given I navigate to "${baseUrl}/sessions?fixture=ticket_lifecycle_no_events"
    And I wait for network idle
    Then "[data-testid='triage-ticket-item'][data-ticket-id='default-lifecycle-ticket'] [data-testid='ticket-lifecycle-stage']" should have text "Open"
