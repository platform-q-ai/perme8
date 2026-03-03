# PRD: Optimistic Sessions UI Updates with Durable Client State

## Source
- Ticket: #330
- Title: `feat: add optimistic session UI updates with durable client state`

## User Story
As a user working in Sessions, I want my submitted actions to appear immediately and survive reloads so I can keep track of in-flight intent while backend processing catches up.

## Scope
- Owning domain app: `agents`
- Owning interface app: `agents_web`
- Primary surface: Sessions LiveView and browser hooks in `agents_web`

## Scenarios

### Scenario: optimistic follow-up appears immediately
Given I am viewing an existing session
And the current session can accept follow-up input
When I submit a follow-up instruction
Then the follow-up instruction appears immediately in the chat timeline with a pending state
And the UI indicates that backend acknowledgement is still pending

### Scenario: explicit async command payload is emitted
Given I am viewing a session that can accept input
When I submit an instruction
Then the UI emits an explicit command payload for asynchronous backend processing
And the payload includes a correlation key that can be matched with backend acknowledgements

### Scenario: optimistic state survives full page reload
Given I have one or more optimistic entries waiting for backend acknowledgement
When I fully reload the browser page
Then the optimistic entries are restored in the Sessions UI
And each restored entry preserves its pending status and correlation key

### Scenario: successful backend acknowledgement confirms optimistic entry
Given I have an optimistic entry with a correlation key
When the backend reports success for that entry
Then the optimistic entry is deterministically reconciled to confirmed
And duplicate message rendering is prevented

### Scenario: failed backend acknowledgement marks entry retriable or rolled back
Given I have an optimistic entry with a correlation key
When the backend reports a failure for that entry
Then the entry is deterministically reconciled as retriable or rolled back
And the user sees a clear failure status in the UI

### Scenario: reconnect handling remains deterministic
Given a session disconnect or reconnect occurs while optimistic entries exist
When the UI reconnects to LiveView updates
Then optimistic and authoritative states reconcile deterministically
And no optimistic entry is duplicated or orphaned

## Constraints
- Keep ownership boundaries within `agents` and `agents_web` per `docs/app_ownership.md`
- Preserve existing Sessions behavior for non-optimistic flows
