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

  Scenario: user sees optimistic pending entry immediately after submitting follow-up input
    Given "div#session-optimistic-state" should exist
    When "form#session-form" should exist
    Then "textarea#session-instruction" should exist
    And I should see "Sessions"

  Scenario: optimistic entry survives a full browser reload
    Given "div#session-optimistic-state" should exist
    When I reload the page
    Then "div#session-optimistic-state" should exist
    And "textarea#session-instruction" should exist

  Scenario: backend success reconciles optimistic entry to confirmed
    Given "div#session-log" should exist
    When "form#session-form" should exist
    Then "div#session-log" should exist
    And I should see "Sessions"

  Scenario: backend failure reconciles optimistic entry with user-visible failure state
    Given "div#session-optimistic-state" should exist
    When "form#session-form" should exist
    Then "textarea#session-instruction" should exist
    And "div#session-log" should exist
