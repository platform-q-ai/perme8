@security @sessions @aggregate-root
Feature: Session aggregate root security
  As a platform owner
  I want sessions, interactions, and container management to enforce proper
  access control and follow security best practices
  So that users cannot access other users' data and the system is resilient
  to common vulnerabilities

  # ---------------------------------------------------------------------------
  # Authentication
  # ---------------------------------------------------------------------------

  Scenario: Unauthenticated user cannot list sessions
    Given I am not authenticated
    When I attempt to list sessions
    Then the request should be rejected as unauthorized

  Scenario: Unauthenticated user cannot create a session
    Given I am not authenticated
    When I attempt to create a session
    Then the request should be rejected as unauthorized

  Scenario: Unauthenticated user cannot view interaction history
    Given I am not authenticated
    When I attempt to view interaction history for a session
    Then the request should be rejected as unauthorized

  # ---------------------------------------------------------------------------
  # User Isolation -- Sessions
  # ---------------------------------------------------------------------------

  Scenario: User cannot access another user's session
    Given user A has sessions
    And I am authenticated as user B
    When I attempt to access user A's session
    Then the action should be rejected as forbidden

  Scenario: User cannot pause another user's session
    Given user A has an active session
    And I am authenticated as user B
    When I attempt to pause user A's session
    Then the action should be rejected as forbidden

  Scenario: User cannot resume another user's session
    Given user A has a paused session
    And I am authenticated as user B
    When I attempt to resume user A's session
    Then the action should be rejected as forbidden

  Scenario: User cannot delete another user's session
    Given user A has a session
    And I am authenticated as user B
    When I attempt to delete user A's session
    Then the action should be rejected as forbidden

  # ---------------------------------------------------------------------------
  # User Isolation -- Interactions
  # ---------------------------------------------------------------------------

  Scenario: User cannot view another user's interaction history
    Given user A has a session with interactions
    And I am authenticated as user B
    When I attempt to list interactions for user A's session
    Then the action should be rejected as forbidden

  Scenario: User cannot answer another user's pending question
    Given user A has a session with a pending question
    And I am authenticated as user B
    When I attempt to answer the pending question on user A's session
    Then the action should be rejected as forbidden

  Scenario: User cannot send follow-up messages to another user's session
    Given user A has a running session
    And I am authenticated as user B
    When I attempt to send a follow-up message to user A's session
    Then the action should be rejected as forbidden

  # ---------------------------------------------------------------------------
  # Container Security
  # ---------------------------------------------------------------------------

  Scenario: Session response does not expose Docker host paths
    Given I am authenticated
    When I create a session and receive the response
    Then the response should not contain Docker host paths or mount points
    And the response should not contain container environment variables

  Scenario: Session response does not leak internal port mappings
    Given I am authenticated with a running session
    When I view the session details
    Then the response should not contain internal Docker network addresses
    And only the session's mapped port should be visible

  # ---------------------------------------------------------------------------
  # Data Integrity -- Interaction Immutability
  # ---------------------------------------------------------------------------

  Scenario: Delivered interaction records cannot be modified
    Given I am authenticated with a session that has delivered interactions
    When I attempt to modify a delivered interaction's content
    Then the modification should be rejected
    And the original interaction data should be preserved

  Scenario: Session deletion cascades to interactions cleanly
    Given I am authenticated with a session that has interactions
    When I delete the session
    Then all associated interaction records should also be deleted
    And no orphaned interaction records should remain in the database

  # ---------------------------------------------------------------------------
  # Security Headers and Transport
  # ---------------------------------------------------------------------------

  # NOTE: General security headers for the sessions page are already covered
  # in queue-orchestration.security.feature. This scenario focuses specifically
  # on API responses not leaking server version information.

  Scenario: Session API responses do not leak server version information
    Given I am authenticated
    When I request session data via the API
    Then the response should include proper security headers
    And the response should not include server version information
