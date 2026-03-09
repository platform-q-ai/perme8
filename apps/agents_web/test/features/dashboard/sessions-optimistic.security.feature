@security @sessions @optimistic
Feature: Security posture for optimistic session command handling
  As a platform owner
  I want optimistic session command flows to enforce auth and isolation
  So that durable client state does not bypass access controls

  Scenario: unauthenticated user cannot submit optimistic session commands
    Given I am not authenticated
    When I attempt to submit an optimistic session command
    Then the request should be rejected as unauthorized

  Scenario: user cannot reconcile another user's optimistic entries
    Given user A has optimistic entries for a session
    And I am authenticated as user B
    When I attempt to confirm or fail user A optimistic entry correlation keys
    Then the action should be rejected as forbidden

  Scenario: optimistic command payload rejects malformed correlation keys
    Given I am authenticated
    When I submit an optimistic command payload with malformed correlation data
    Then the payload should be rejected by validation
    And no optimistic entry should be accepted for processing

  Scenario: durable optimistic state does not expose sensitive content across users
    Given optimistic entries are persisted for user A
    When user B loads Sessions UI
    Then user B should not see user A optimistic entries or metadata
