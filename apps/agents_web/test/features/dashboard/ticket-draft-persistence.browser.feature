@browser @sessions @tickets @drafts
Feature: Ticket-scoped draft persistence and explicit session-ticket association
  As a user working with tickets
  I want each ticket to own its own chat/ticket text area state that survives
  server restarts and page reloads, and I want sessions to be properly associated
  with tickets via explicit parameters rather than regex parsing of instruction text
  So that my in-progress messages are never lost and ticket-session links are reliable

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle

  # ---------------------------------------------------------------------------
  # Per-ticket draft state persistence
  # ---------------------------------------------------------------------------

  Scenario: Draft text persists across page reloads for a specific ticket
    Given I wait for "[data-testid='triage-ticket-item-101']" to be visible
    When I click "[data-testid='triage-ticket-item-101']"
    And I wait for network idle
    And I wait for "#session-instruction" to be visible
    And I fill "#session-instruction" with "investigate the SSO provider"
    And I reload the page
    And I wait for network idle
    And I wait for "[data-testid='triage-ticket-item-101']" to be visible
    When I click "[data-testid='triage-ticket-item-101']"
    And I wait for network idle
    And I wait for "#session-instruction" to be visible
    And I wait for 2 seconds
    Then "#session-instruction" should have value "investigate the SSO provider"

  Scenario: Switching between tickets preserves each ticket's draft text
    Given I wait for "[data-testid='triage-ticket-item-101']" to be visible
    When I click "[data-testid='triage-ticket-item-101']"
    And I wait for network idle
    And I wait for "#session-instruction" to be visible
    And I fill "#session-instruction" with "fix the login flow"
    When I click "[data-testid='triage-ticket-item-102']"
    And I wait for network idle
    And I wait for "#session-instruction" to be visible
    And I wait for 1 seconds
    And I fill "#session-instruction" with "add dark mode toggle"
    When I click "[data-testid='triage-ticket-item-101']"
    And I wait for network idle
    And I wait for "#session-instruction" to be visible
    And I wait for 1 seconds
    Then "#session-instruction" should have value "fix the login flow"
    When I click "[data-testid='triage-ticket-item-102']"
    And I wait for network idle
    And I wait for "#session-instruction" to be visible
    And I wait for 1 seconds
    Then "#session-instruction" should have value "add dark mode toggle"

  Scenario: Draft text survives server restart (simulated via page reload)
    Given I wait for "[data-testid='triage-ticket-item-101']" to be visible
    When I click "[data-testid='triage-ticket-item-101']"
    And I wait for network idle
    And I wait for "#session-instruction" to be visible
    And I fill "#session-instruction" with "check the auth module"
    And I reload the page
    And I wait for network idle
    And I wait for "[data-testid='triage-ticket-item-101']" to be visible
    When I click "[data-testid='triage-ticket-item-101']"
    And I wait for network idle
    And I wait for "#session-instruction" to be visible
    And I wait for 2 seconds
    Then "#session-instruction" should have value "check the auth module"

  Scenario: Submitting a message clears the draft for that ticket
    Given I wait for "[data-testid='triage-ticket-item-101']" to be visible
    When I click "[data-testid='triage-ticket-item-101']"
    And I wait for network idle
    And I wait for "#session-instruction" to be visible
    And I fill "#session-instruction" with "fix the login"
    And I focus on "#session-instruction"
    And I press "Enter"
    And I wait for network idle
    And I wait for 2 seconds
    Then "#session-instruction" should have value ""

  # ---------------------------------------------------------------------------
  # Explicit session-ticket association
  # ---------------------------------------------------------------------------

  Scenario: Play button associates the session with the ticket explicitly
    Given I wait for "[data-testid='start-ticket-session-101']" to be visible
    When I click "[data-testid='start-ticket-session-101']"
    And I wait for network idle
    Then I wait for "[data-testid='build-ticket-item-101']" to be visible

  Scenario: Chat tab message with a ticket selected creates an explicitly linked session
    Given I wait for "[data-testid='triage-ticket-item-102']" to be visible
    When I click "[data-testid='triage-ticket-item-102']"
    And I wait for network idle
    And I wait for "#session-instruction" to be visible
    And I click "[role='tab'][data-tab-id='chat']"
    And I wait for network idle
    And I fill "#session-instruction" with "fix this bug"
    And I focus on "#session-instruction"
    And I press "Enter"
    And I wait for network idle
    Then I wait for "[data-testid='build-ticket-item-102']" to be visible

  Scenario: Ticket tab message with a ticket selected creates an explicitly linked session
    Given I wait for "[data-testid='triage-ticket-item-103']" to be visible
    When I click "[data-testid='triage-ticket-item-103']"
    And I wait for network idle
    And I wait for "#session-instruction" to be visible
    And I click "[role='tab'][data-tab-id='ticket']"
    And I wait for network idle
    And I fill "#session-instruction" with "please investigate this issue"
    And I focus on "#session-instruction"
    And I press "Enter"
    And I wait for network idle
    Then I wait for "[data-testid='build-ticket-item-103']" to be visible

  Scenario: False ticket references in message text do not cause wrong associations
    Given I wait for "[data-testid='triage-ticket-item-104']" to be visible
    When I click "[data-testid='triage-ticket-item-104']"
    And I wait for network idle
    And I wait for "#session-instruction" to be visible
    And I click "[role='tab'][data-tab-id='chat']"
    And I wait for network idle
    And I fill "#session-instruction" with "fix issue #5 in the CSS"
    And I focus on "#session-instruction"
    And I press "Enter"
    And I wait for network idle
    # Ticket 104 should have moved to build queue (associated with the session)
    Then I wait for "[data-testid='build-ticket-item-104']" to be visible
    # Ticket 5 should NOT exist in the build queue (false reference)
    And "[data-testid='build-ticket-item-5']" should not exist
