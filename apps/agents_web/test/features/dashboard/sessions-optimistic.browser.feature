@browser @sessions @optimistic
Feature: Optimistic session updates in the Sessions UI
  As a sessions user
  I want my actions to appear immediately and survive reloads
  So that I can trust in-flight intent while backend processing catches up

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle

  Scenario: optimistic new session appears in sidebar immediately
    Given "div#session-optimistic-state" should exist
    And "form#sidebar-new-session-form" should exist
    When I fill "textarea#sidebar-new-session-instruction" with "Optimistic sidebar enqueue"
    And I focus on "textarea#sidebar-new-session-instruction"
    And I press "Enter"
    Then I should see "Optimistic sidebar enqueue"

  Scenario: optimistic entry survives a full browser reload
    Given "div#session-optimistic-state" should exist
    And "form#sidebar-new-session-form" should exist
    When I fill "textarea#sidebar-new-session-instruction" with "Reload optimistic enqueue"
    And I focus on "textarea#sidebar-new-session-instruction"
    And I press "Enter"
    And I should see "Reload optimistic enqueue"
    When I reload the page
    Then "div#session-optimistic-state" should exist
    And I should see "Reload optimistic enqueue"

  Scenario: backend reconciliation removes optimistic placeholder
    Given "div#session-log" should exist
    And "form#sidebar-new-session-form" should exist
    When I fill "textarea#sidebar-new-session-instruction" with "Reconcile optimistic enqueue"
    And I focus on "textarea#sidebar-new-session-instruction"
    And I press "Enter"
    When I wait for 2 seconds
    Then "[data-slot-state='optimistic-queued']" should not exist

  Scenario: initial user instruction is rendered exactly once in chat timeline
    Given "div#session-log" should exist
    When I wait for 1 seconds
    Then "[data-testid='session-initial-instruction']" should exist
    And "#session-log [data-testid='session-initial-instruction'] ~ [data-testid='session-initial-instruction']" should not exist
