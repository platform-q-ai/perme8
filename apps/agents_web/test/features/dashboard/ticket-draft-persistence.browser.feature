@browser @sessions @tickets @drafts @wip
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
    Given I wait for "[data-testid='ticket-card']" to be visible
    When I click the first "[data-testid='ticket-card']"
    And I wait for network idle
    And I fill "form#session-form textarea" with "investigate the SSO provider"
    And I reload the page
    And I wait for network idle
    And I click the first "[data-testid='ticket-card']"
    And I wait for network idle
    Then "form#session-form textarea" should contain text "investigate the SSO provider"

  Scenario: Switching between tickets preserves each ticket's draft text
    Given I wait for "[data-testid='ticket-card']" to be visible
    When I click the first "[data-testid='ticket-card']"
    And I wait for network idle
    And I fill "form#session-form textarea" with "fix the login flow"
    And I click the second "[data-testid='ticket-card']"
    And I wait for network idle
    And I fill "form#session-form textarea" with "add dark mode toggle"
    And I click the first "[data-testid='ticket-card']"
    And I wait for network idle
    Then "form#session-form textarea" should contain text "fix the login flow"
    When I click the second "[data-testid='ticket-card']"
    And I wait for network idle
    Then "form#session-form textarea" should contain text "add dark mode toggle"

  Scenario: Draft text survives server restart (simulated via page reload)
    Given I wait for "[data-testid='ticket-card']" to be visible
    When I click the first "[data-testid='ticket-card']"
    And I wait for network idle
    And I fill "form#session-form textarea" with "check the auth module"
    And I reload the page
    And I wait for network idle
    And I click the first "[data-testid='ticket-card']"
    And I wait for network idle
    Then "form#session-form textarea" should contain text "check the auth module"

  Scenario: Submitting a message clears the draft for that ticket
    Given I wait for "[data-testid='ticket-card']" to be visible
    When I click the first "[data-testid='ticket-card']"
    And I wait for network idle
    And I fill "form#session-form textarea" with "fix the login"
    And I focus on "form#session-form textarea"
    And I press "Enter"
    And I wait for network idle
    Then "form#session-form textarea" should have value ""
    When I reload the page
    And I wait for network idle
    And I click the first "[data-testid='ticket-card']"
    And I wait for network idle
    Then "form#session-form textarea" should have value ""

  # ---------------------------------------------------------------------------
  # Explicit session-ticket association
  # ---------------------------------------------------------------------------

  Scenario: Play button associates the session with the ticket explicitly
    Given I wait for "[data-testid='ticket-card']" to be visible
    When I click "[data-testid='ticket-start-session']" on the first ticket card
    And I wait for network idle
    Then the ticket card should show an associated session lifecycle badge
    And the session should be linked to the ticket

  Scenario: Chat tab message with a ticket selected creates an explicitly linked session
    Given I wait for "[data-testid='ticket-card']" to be visible
    When I click the first "[data-testid='ticket-card']"
    And I wait for network idle
    And I click "[role='tab'][data-tab-id='chat']"
    And I wait for network idle
    And I fill "form#session-form textarea" with "fix this bug"
    And I focus on "form#session-form textarea"
    And I press "Enter"
    And I wait for network idle
    Then the ticket card should show an associated session lifecycle badge

  Scenario: Ticket tab message with a ticket selected creates an explicitly linked session
    Given I wait for "[data-testid='ticket-card']" to be visible
    When I click the first "[data-testid='ticket-card']"
    And I wait for network idle
    And I click "[role='tab'][data-tab-id='ticket']"
    And I wait for network idle
    And I fill "form#session-form textarea" with "please investigate this issue"
    And I focus on "form#session-form textarea"
    And I press "Enter"
    And I wait for network idle
    Then the ticket card should show an associated session lifecycle badge

  Scenario: False ticket references in message text do not cause wrong associations
    Given I wait for "[data-testid='ticket-card']" to be visible
    When I click the first "[data-testid='ticket-card']"
    And I wait for network idle
    And I click "[role='tab'][data-tab-id='chat']"
    And I wait for network idle
    And I fill "form#session-form textarea" with "fix issue #5 in the CSS"
    And I focus on "form#session-form textarea"
    And I press "Enter"
    And I wait for network idle
    Then the first ticket card should show an associated session
    And the session should NOT be associated with a different ticket

  Scenario: Session-ticket link persists across page reload
    Given I wait for "[data-testid='ticket-card']" to be visible
    And the first ticket has an associated session
    When I reload the page
    And I wait for network idle
    Then the first ticket card should still show its associated session lifecycle badge
    When I click the first "[data-testid='ticket-card']"
    And I wait for network idle
    Then the session detail panel should show the linked session's chat log

  Scenario: All three entry points produce consistent ticket associations
    Given I wait for "[data-testid='ticket-card']" to be visible
    # Via play button
    When I click "[data-testid='ticket-start-session']" on the first ticket card
    And I wait for network idle
    Then the first ticket card should show an associated session
    # Via chat tab
    When I click the second "[data-testid='ticket-card']"
    And I wait for network idle
    And I click "[role='tab'][data-tab-id='chat']"
    And I fill "form#session-form textarea" with "investigate this"
    And I focus on "form#session-form textarea"
    And I press "Enter"
    And I wait for network idle
    Then the second ticket card should show an associated session
    # Via ticket tab
    When I click the third "[data-testid='ticket-card']"
    And I wait for network idle
    And I click "[role='tab'][data-tab-id='ticket']"
    And I fill "form#session-form textarea" with "look into this"
    And I focus on "form#session-form textarea"
    And I press "Enter"
    And I wait for network idle
    Then the third ticket card should show an associated session
