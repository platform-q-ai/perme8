@browser @sessions @tickets @queue
Feature: Unified ticket queue tracking
  As a developer using the sessions UI
  I want tickets to remain as a single entity as they move through the queue
  So that I can track ticket progress without confusion from duplicate entries

  A ticket is the primary entity. When a ticket has an associated session
  (identified by a linked task_id), it gains additional UI affordances based
  on the session's lifecycle state — but it never splits into a separate
  "session card" in another column. The ticket card is the single source of
  truth in the board.

  Background:
    Given I am logged in as a user with an active workspace

  # --- Core invariant: tickets are singular entities on the board ---

  Scenario: Idle ticket appears only in the triage column
    Given I have ticket #42 "Fix login bug" in the triage column
    And ticket #42 has no associated session
    When I navigate to the Sessions page
    Then I should see ticket #42 in the triage column
    And ticket #42 should not appear in the build column

  Scenario: Queued ticket moves out of triage and into the build column
    Given I have ticket #42 "Fix login bug" in the triage column
    When I start a session for ticket #42
    And the session is queued
    Then ticket #42 should appear in the build column
    And ticket #42 should not appear in the triage column
    And the ticket card should show the "Queued" lifecycle badge

  Scenario: Running ticket appears only in the build column
    Given ticket #42 has a running session
    When I navigate to the Sessions page
    Then ticket #42 should appear in the build column with variant "in_progress"
    And ticket #42 should not appear in the triage column
    And the ticket card should show the "Running" lifecycle badge

  Scenario: Ticket with pending session appears only in the build column
    Given ticket #42 has a session with status "pending"
    When I navigate to the Sessions page
    Then ticket #42 should appear in the build column with variant "in_progress"
    And ticket #42 should not appear in the triage column

  Scenario: Ticket never appears simultaneously in triage and build columns
    Given ticket #42 has a session with status "queued"
    When I navigate to the Sessions page
    Then the total count of ticket #42 cards across both columns should be exactly 1

  # --- Session state decorates the ticket card ---

  Scenario: Queued ticket card shows session queue position
    Given ticket #42 has a session with status "queued"
    And the session is at queue position 3
    When I navigate to the Sessions page
    Then the ticket #42 card in the build column should show queue position 3

  Scenario: Queued ticket in warm zone shows warming indicator
    Given ticket #42 has a session with status "queued"
    And the session is in the warm zone
    And the session is warming up
    When I navigate to the Sessions page
    Then the ticket #42 card should show the warming animation
    And the ticket card should show the "Warming up" lifecycle badge

  Scenario: Running ticket card shows container stats
    Given ticket #42 has a running session with container stats
    When I navigate to the Sessions page
    Then the ticket #42 card should display container CPU and memory bars
    And the ticket card should show a duration timer

  Scenario: Running ticket card shows progress bar from todo items
    Given ticket #42 has a running session
    And the session has 3 of 5 todo items completed
    When I navigate to the Sessions page
    Then the ticket #42 card should display a progress bar at 60%

  Scenario: Awaiting feedback ticket returns to triage with feedback indicator
    Given ticket #42 has a session with status "awaiting_feedback"
    When I navigate to the Sessions page
    Then ticket #42 should appear in the triage column
    And the ticket card should show the "Awaiting feedback" lifecycle badge
    And ticket #42 should be sorted to the top of the triage column

  Scenario: Completed ticket returns to triage with completed indicator
    Given ticket #42 has a session with status "completed"
    When I navigate to the Sessions page
    Then ticket #42 should appear in the triage column
    And the ticket card should show the "Completed" lifecycle badge
    And ticket #42 should not appear in the build column

  Scenario: Failed ticket returns to triage with error indicator
    Given ticket #42 has a session with status "failed"
    When I navigate to the Sessions page
    Then ticket #42 should appear in the triage column
    And the ticket card should show the "Failed" lifecycle badge
    And ticket #42 should not appear in the build column

  Scenario: Cancelled ticket returns to triage
    Given ticket #42 has a session with status "cancelled"
    When I navigate to the Sessions page
    Then ticket #42 should appear in the triage column
    And the ticket card should show the "Cancelled" lifecycle badge

  # --- No orphan session cards for ticket-linked sessions ---

  Scenario: Session linked to a ticket does not render as a standalone session card
    Given ticket #42 has a running session
    When I navigate to the Sessions page
    Then I should not see a standalone non-ticket session card for ticket #42's session
    And ticket #42 should appear as a ticket card in the build column

  Scenario: Session linked to a ticket via task instruction does not duplicate
    Given a session exists with instruction "pick up ticket #42 using the relevant skill"
    And ticket #42 exists in the triage column
    When I navigate to the Sessions page
    Then ticket #42 should appear once on the board
    And no standalone session card should exist with instruction matching ticket #42

  # --- Real-time transitions maintain singular tracking ---

  Scenario: Ticket transitions from triage to build in real-time when session starts
    Given ticket #42 is in the triage column with no session
    When I start a session for ticket #42
    Then ticket #42 should animate out of the triage column
    And ticket #42 should appear in the build column
    And the triage ticket count should decrease by 1

  Scenario: Ticket transitions from build to triage when session completes
    Given ticket #42 has a running session in the build column
    When the session completes
    Then ticket #42 should move from the build column to the triage column
    And the ticket card should update to show the "Completed" lifecycle badge

  Scenario: Ticket transitions from build to triage when session fails
    Given ticket #42 has a running session in the build column
    When the session fails
    Then ticket #42 should move from the build column to the triage column
    And the ticket card should update to show the "Failed" lifecycle badge

  Scenario: Ticket transitions from build to triage when session is cancelled
    Given ticket #42 has a running session in the build column
    When I cancel the session
    Then ticket #42 should move from the build column to the triage column
    And the ticket card should update to show the "Cancelled" lifecycle badge

  # --- Selecting a ticket with an active session ---

  Scenario: Clicking a ticket card in the build column opens its session chat
    Given ticket #42 has a running session
    When I navigate to the Sessions page
    And I click the ticket #42 card in the build column
    Then the detail panel should show the session chat log
    And the tab bar should show both "Chat" and "Ticket" tabs
    And the "Chat" tab should be active

  Scenario: Clicking a ticket card in triage with a completed session opens the chat
    Given ticket #42 has a session with status "completed"
    When I click the ticket #42 card in the triage column
    Then the detail panel should show the session chat log
    And the tab bar should show both "Chat" and "Ticket" tabs

  # --- Removing a ticket from the queue ---

  Scenario: Removing a queued ticket from the build column returns it to triage
    Given ticket #42 has a session with status "queued"
    And ticket #42 appears in the build column
    When I remove ticket #42 from the queue
    Then ticket #42 should appear in the triage column
    And ticket #42 should not appear in the build column
    And the session should be cancelled

  # --- Filter interactions ---

  Scenario: Running filter shows tickets with running sessions
    Given ticket #42 has a running session
    And ticket #99 has no session
    When I click the "Running" filter
    Then ticket #42 should be visible
    And ticket #99 should not be visible

  Scenario: Queued filter shows tickets with queued sessions
    Given ticket #42 has a session with status "queued"
    And ticket #99 has a running session
    When I click the "Queued" filter
    Then ticket #42 should be visible
    And ticket #99 should not be visible

  Scenario: Open filter shows idle tickets and tickets with active sessions
    Given ticket #42 has a running session
    And ticket #99 has no session
    And ticket #77 has a session with status "completed"
    When I click the "Open" filter
    Then ticket #42 should be visible
    And ticket #99 should be visible
    And ticket #77 should be visible
