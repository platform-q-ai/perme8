@browser @sessions @ticket-hierarchy @wip
Feature: Ticket subticket hierarchy in Sessions triage
  As a developer using the Sessions UI
  I want tickets with sub-issues displayed hierarchically in the triage column
  So that I can understand the breakdown of work and track progress on decomposed tickets

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle

  Scenario: Root tickets display at top level in triage column
    Then "#triage-lane [data-testid^='triage-ticket-item-'][data-ticket-depth='0']" should exist
    And "#triage-lane > [data-testid^='triage-ticket-item-'][data-ticket-depth='1']" should not exist

  Scenario: Parent ticket shows subticket count indicator
    Then I should see "3 sub-issues"

  Scenario: Subtickets render nested under parent ticket
    Then "#triage-lane [data-testid^='triage-ticket-item-'][data-ticket-depth='1']" should exist
    And "#triage-lane [data-testid^='triage-ticket-item-'][data-ticket-depth='1']" should have class "subticket-card"

  Scenario: Collapsible parent ticket in triage column
    When I click "#triage-lane [data-testid='triage-parent-toggle']"
    Then "#triage-lane [data-testid='triage-subticket-list']" should be hidden
    When I click "#triage-lane [data-testid='triage-parent-toggle']"
    Then "#triage-lane [data-testid='triage-subticket-list']" should be visible

  Scenario: Viewing parent ticket detail shows subticket list
    When I click "#triage-lane [data-testid^='triage-ticket-item-'][data-has-subissues='true']"
    And I wait for network idle
    Then "[data-testid='ticket-detail-panel']" should be visible
    And "[data-testid='ticket-detail-body']" should exist
    And "[data-testid='ticket-detail-labels']" should exist
    And I should see "Sub-issues"
    And "[data-testid='ticket-detail-subissues']" should exist

  Scenario: Clicking a subticket in detail panel navigates to its detail
    When I click "#triage-lane [data-testid^='triage-ticket-item-'][data-has-subissues='true']"
    And I wait for network idle
    When I click "[data-testid='ticket-detail-subissues'] [data-testid^='ticket-subissue-item-']:first-child"
    Then "[data-testid='ticket-detail-panel']" should be visible
    And "[data-testid='ticket-detail-panel'] [data-ticket-type='subticket']" should exist

  Scenario: Closed parent ticket shows subticket state summary
    When I click "#triage-lane [data-testid^='triage-ticket-item-'][data-ticket-state='closed'][data-has-subissues='true']"
    Then I should see "2/3 closed"

  Scenario: Subticket drag-and-drop within parent group
    Then "#triage-lane [data-triage-ticket-card][data-ticket-depth='1']" should have attribute "draggable" with value "true"
    When I drag "#triage-lane [data-triage-ticket-card][data-ticket-depth='1']:last-child" to "#triage-lane [data-triage-ticket-card][data-ticket-depth='1']:first-child"
    Then "#triage-lane [data-triage-ticket-card][data-ticket-depth='1']" should exist

  Scenario: Viewing a subticket shows breadcrumb to parent
    When I click "#triage-lane [data-testid^='triage-ticket-item-'][data-ticket-depth='1']"
    And I wait for network idle
    Then "[data-testid='ticket-detail-parent-breadcrumb']" should be visible
    And I should see "Parent ticket"

  Scenario: Ticket hierarchy reflects GitHub sub-issue sync
    When I click the "Sync tickets" button
    And I wait for network idle
    Then "#triage-lane [data-testid^='triage-ticket-item-'][data-has-subissues='true']" should exist
    And "#triage-lane [data-testid^='triage-ticket-item-'][data-ticket-depth='1']" should exist
    And I should see "sub-issues"
