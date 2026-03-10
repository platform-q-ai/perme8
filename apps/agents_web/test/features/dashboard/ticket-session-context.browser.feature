@browser @sessions @tickets @context @wip
Feature: Ticket-session context preservation
  As a developer starting a chat from a ticket
  I want the message to include the ticket's context and maintain the association
  So that the agent has full context and the ticket remains linked to its session

  When a user types a message while viewing a ticket (either from the ticket tab
  or with a ticket selected), the submitted instruction must include the ticket's
  context (number, title, body, labels) and the resulting session must be durably
  linked to that ticket via the persisted task_id association.

  Background:
    Given I am logged in as a user with an active workspace

  # --- Ticket context injection into instructions ---

  Scenario: Starting a new session from the ticket tab includes ticket context
    Given ticket #42 "Fix login bug" exists with body "Users cannot log in with SSO"
    And ticket #42 has labels "bug" and "auth"
    And I have selected ticket #42
    And I am on the "Ticket" tab
    When I type "Please investigate this issue" in the instruction input
    And I submit the instruction
    Then the created task instruction should contain a reference to ticket #42
    And the created task instruction should include the ticket title "Fix login bug"
    And the created task instruction should include the ticket body
    And the created task instruction should include the ticket labels

  Scenario: Starting a new session from the chat tab with a ticket selected includes ticket reference
    Given ticket #42 "Fix login bug" exists
    And I have selected ticket #42
    And I am on the "Chat" tab
    When I type "Fix this bug" in the instruction input
    And I submit the instruction
    Then the created task instruction should contain a reference to ticket #42

  Scenario: Sending a follow-up message on an existing ticket session preserves context
    Given ticket #42 has a running session
    And I have selected ticket #42's session
    When I type "Also check the logout flow" in the instruction input
    And I submit the instruction
    Then the follow-up message should be sent to the existing session
    And ticket #42 should remain associated with the session

  Scenario: Starting a session via the "Start Session" button on a ticket card includes full context
    Given ticket #42 "Fix login bug" exists with body "Users cannot log in with SSO"
    And ticket #42 has no associated session
    When I click the "Start Session" button on ticket #42's card
    Then a new task should be created with instruction referencing ticket #42
    And the task instruction should include the ticket title
    And the task instruction should include the ticket body
    And ticket #42 should be linked to the new task via persisted task_id

  # --- Durable ticket-task association ---

  Scenario: New session created from a ticket is persisted in the database
    Given ticket #42 "Fix login bug" exists
    When I start a session for ticket #42
    Then the ticket's task_id column should be set to the new task's ID
    And reloading the page should show ticket #42 still linked to its session

  Scenario: Ticket-task link survives page reload
    Given ticket #42 has a running session linked via task_id
    When I reload the page
    Then ticket #42 should still show the running session's lifecycle state
    And clicking ticket #42 should open its session's chat log

  Scenario: Ticket-task link survives ticket sync from GitHub
    Given ticket #42 has a running session linked via task_id
    When a ticket sync from GitHub completes
    Then ticket #42 should still be linked to its session
    And the ticket card should still show the session's lifecycle badge

  Scenario: Resuming a completed ticket session preserves the ticket association
    Given ticket #42 has a session with status "completed"
    And the ticket is linked to the session via task_id
    When I select ticket #42
    And I type "Continue with the next step" in the instruction input
    And I submit the instruction
    Then the resumed session should still be associated with ticket #42
    And ticket #42 should move to the build column

  # --- Context format for the agent ---

  Scenario: Ticket context is formatted as structured markdown for the agent
    Given ticket #42 "Fix login bug" exists with body "Users cannot log in with SSO"
    And ticket #42 has labels "bug" and "auth"
    And ticket #42 has sub-tickets #43 "Fix SSO provider" and #44 "Fix session cookies"
    When I start a session for ticket #42
    Then the task instruction should contain a structured ticket context block
    And the context block should include the ticket number
    And the context block should include the ticket title
    And the context block should include the ticket body
    And the context block should include the ticket labels
    And the context block should include the sub-ticket numbers and titles

  Scenario: Sub-ticket context includes parent ticket reference
    Given ticket #43 "Fix SSO provider" is a sub-ticket of ticket #42 "Fix login bug"
    When I start a session for ticket #43
    Then the task instruction should reference parent ticket #42
    And the context block should include the sub-ticket's own body

  # --- Edge cases ---

  Scenario: Manually typed instruction with ticket reference still links the ticket
    Given ticket #42 "Fix login bug" exists
    And I am composing a new session
    When I type "pick up ticket #42 and fix it" in the instruction input
    And I submit the instruction
    Then ticket #42 should be linked to the new task via persisted task_id

  Scenario: Instruction without ticket reference does not inject ticket context when no ticket is selected
    Given I am composing a new session
    And no ticket is selected
    When I type "Refactor the auth module" in the instruction input
    And I submit the instruction
    Then the task instruction should be exactly "Refactor the auth module"
    And no ticket should be linked to the new task

  Scenario: Sending a message on a ticket session that has been cancelled creates a new session with context
    Given ticket #42 has a session with status "cancelled"
    And I have selected ticket #42
    When I type "Try again with a different approach" in the instruction input
    And I submit the instruction
    Then a new task should be created with ticket #42 context
    And ticket #42's task_id should be updated to the new task's ID
    And the old cancelled session should not be associated with ticket #42

  Scenario: Multiple tickets can each have their own independent session
    Given ticket #42 has a running session
    And ticket #99 has no session
    When I start a session for ticket #99
    Then ticket #42 should remain linked to its own session
    And ticket #99 should be linked to its own separate session
    And both tickets should appear in the build column independently
