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
    Given the Sessions UI is showing an active session
    When I submit a follow-up instruction in the session input
    Then I should see that instruction immediately in the session timeline
    And I should see a visible pending status for that optimistic entry

  Scenario: optimistic entry survives a full browser reload
    Given I have submitted a follow-up instruction that is still pending acknowledgement
    When I reload the page
    Then I should still see the same optimistic entry in the session timeline
    And it should still show a pending status

  Scenario: backend success reconciles optimistic entry to confirmed
    Given an optimistic entry is visible in the session timeline
    When the backend acknowledgement for that entry succeeds
    Then the entry should be shown as confirmed instead of pending
    And the entry should not be duplicated in the timeline

  Scenario: backend failure reconciles optimistic entry with user-visible failure state
    Given an optimistic entry is visible in the session timeline
    When the backend acknowledgement for that entry fails
    Then the entry should be marked as failed or retriable
    And I should see a clear failure status for that entry
