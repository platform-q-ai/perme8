@http @sessions @aggregate-root @wip
Feature: Session aggregate root with durable interactions, ticket linking, and container management
  As a user managing agent sessions via the API
  I want sessions, tasks, containers, and interactions to be durably tracked
  So that session state, interaction history, and ticket links are reliable
  and survive server restarts

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"
    And I set bearer token to "${valid-user-token}"
    And I set header "X-Workspace-Id" to "${active-workspace-id}"

  # ---------------------------------------------------------------------------
  # Phase 1: Session Aggregate Root -- CRUD
  # ---------------------------------------------------------------------------

  Scenario: List sessions returns session entities from sessions table
    When I GET "/internal/sessions"
    Then the response status should be 200
    And the response body path "$.sessions" should be an array
    And the response body path "$.sessions[0].id" should exist
    And the response body path "$.sessions[0].title" should exist
    And the response body path "$.sessions[0].status" should exist
    And the response body path "$.sessions[0].container_status" should exist
    And the response body path "$.sessions[0].container_id" should exist
    And the response body path "$.sessions[0].image" should exist
    And the response body path "$.sessions[0].task_count" should exist

  Scenario: Session detail includes container metadata
    When I GET "/internal/sessions/${session-id}"
    Then the response status should be 200
    And the response body path "$.session.container_id" should exist
    And the response body path "$.session.container_port" should exist
    And the response body path "$.session.container_status" should be one of "pending,starting,running,stopped,removed"
    And the response body path "$.session.image" should exist
    And the response body path "$.session.sdk_session_id" should exist

  Scenario: Session includes lifecycle timestamps
    When I GET "/internal/sessions/${session-id}"
    Then the response status should be 200
    And the response body path "$.session.status" should be one of "active,paused,completed,failed"
    And the response body path "$.session.inserted_at" should exist
    And the response body path "$.session.updated_at" should exist

  Scenario: Tasks reference sessions via foreign key
    When I GET "/internal/sessions/${session-id}/tasks"
    Then the response status should be 200
    And the response body path "$.tasks" should be an array
    And the response body path "$.tasks[0].session_id" should equal "${session-id}"
    And the response body path "$.tasks[0].container_id" should not exist
    And the response body path "$.tasks[0].container_port" should not exist

  # ---------------------------------------------------------------------------
  # Phase 2: Interactions -- Question/Answer/Instruction History
  # ---------------------------------------------------------------------------

  Scenario: Create a question interaction for a session
    When I POST to "/internal/sessions/${session-id}/interactions" with body:
      """
      {
        "type": "question",
        "direction": "outbound",
        "payload": {
          "question": "Which approach should we use?",
          "options": ["Option A", "Option B", "Option C"]
        },
        "correlation_id": "q-001"
      }
      """
    Then the response status should be 201
    And the response body path "$.interaction.id" should exist
    And the response body path "$.interaction.session_id" should equal "${session-id}"
    And the response body path "$.interaction.type" should equal "question"
    And the response body path "$.interaction.direction" should equal "outbound"
    And the response body path "$.interaction.status" should equal "pending"
    And the response body path "$.interaction.correlation_id" should equal "q-001"

  Scenario: Answer a question interaction with matching correlation ID
    Given I POST to "/internal/sessions/${session-id}/interactions" with body:
      """
      {
        "type": "answer",
        "direction": "inbound",
        "payload": {
          "answer": "Option A"
        },
        "correlation_id": "q-001"
      }
      """
    Then the response status should be 201
    And the response body path "$.interaction.type" should equal "answer"
    And the response body path "$.interaction.direction" should equal "inbound"
    And the response body path "$.interaction.correlation_id" should equal "q-001"

  Scenario: List interaction history for a session
    When I GET "/internal/sessions/${session-id}/interactions"
    Then the response status should be 200
    And the response body path "$.interactions" should be an array
    And the response body path "$.interactions[0].type" should exist
    And the response body path "$.interactions[0].direction" should exist
    And the response body path "$.interactions[0].payload" should exist
    And the response body path "$.interactions[0].correlation_id" should exist
    And the response body path "$.interactions[0].status" should exist

  Scenario: Resume instruction is stored as an interaction record
    When I POST to "/internal/sessions/${session-id}/resume" with body:
      """
      {
        "instruction": "Continue with the next step"
      }
      """
    Then the response status should be 200
    And the response body path "$.session.status" should equal "active"
    When I GET "/internal/sessions/${session-id}/interactions"
    Then the response status should be 200
    And the response body path "$.interactions[-1:].type" should equal "instruction"
    And the response body path "$.interactions[-1:].direction" should equal "inbound"

  Scenario: Follow-up message is persisted as an interaction
    When I POST to "/internal/sessions/${session-id}/interactions" with body:
      """
      {
        "type": "queued_response",
        "direction": "inbound",
        "payload": {
          "message": "Also check the logout flow"
        },
        "status": "pending"
      }
      """
    Then the response status should be 201
    And the response body path "$.interaction.type" should equal "queued_response"
    And the response body path "$.interaction.status" should equal "pending"

  # ---------------------------------------------------------------------------
  # Phase 3: Ticket-Session Linking
  # ---------------------------------------------------------------------------

  Scenario: Ticket references session instead of task
    When I GET "/internal/tickets/${ticket-id}"
    Then the response status should be 200
    And the response body path "$.ticket.session_id" should exist
    And the response body path "$.ticket.task_id" should not exist

  Scenario: Creating a session for a ticket sets the link explicitly
    When I POST to "/internal/sessions" with body:
      """
      {
        "instruction": "Fix login bug",
        "ticket_id": "${ticket-id}"
      }
      """
    Then the response status should be 201
    And the response body path "$.session.id" should exist
    When I GET "/internal/tickets/${ticket-id}"
    Then the response status should be 200
    And the response body path "$.ticket.session_id" should equal "${new-session-id}"

  Scenario: Ticket enrichment includes session lifecycle state
    When I GET "/internal/tickets?enriched=true"
    Then the response status should be 200
    And the response body path "$.tickets[0].session_lifecycle_state" should exist
    And the response body path "$.tickets[0].session_container_status" should exist
    And the response body path "$.tickets[0].session_title" should exist

  # ---------------------------------------------------------------------------
  # Phase 4: Transactional Container Management
  # ---------------------------------------------------------------------------

  Scenario: Session creation starts with container status pending
    When I POST to "/internal/sessions" with body:
      """
      {
        "instruction": "Build the feature"
      }
      """
    Then the response status should be 201
    And the response body path "$.session.container_status" should equal "pending"

  Scenario: Container status transitions are persisted on the session
    When I GET "/internal/sessions/${running-session-id}"
    Then the response status should be 200
    And the response body path "$.session.container_status" should be one of "pending,starting,running,stopped,removed"
    And the response body path "$.session.container_id" should exist

  Scenario: Startup reconciliation resolves orphaned containers
    When I POST to "/internal/sessions/reconcile"
    Then the response status should be 200
    And the response body path "$.reconciled" should exist
    And the response body path "$.orphaned_containers_cleaned" should exist
    And the response body path "$.stale_sessions_marked" should exist

  # ---------------------------------------------------------------------------
  # Phase 5: Session Lifecycle State Machine
  # ---------------------------------------------------------------------------

  Scenario: Pausing a session sets status and timestamps
    When I POST to "/internal/sessions/${active-session-id}/pause"
    Then the response status should be 200
    And the response body path "$.session.status" should equal "paused"
    And the response body path "$.session.paused_at" should exist
    And the response body path "$.session.container_status" should equal "stopped"

  Scenario: Resuming a paused session sets status and creates resume task
    When I POST to "/internal/sessions/${paused-session-id}/resume" with body:
      """
      {
        "instruction": "Continue with the next step"
      }
      """
    Then the response status should be 200
    And the response body path "$.session.status" should equal "active"
    And the response body path "$.session.resumed_at" should exist
    And the response body path "$.task.type" should equal "resume"

  Scenario: Invalid lifecycle transition is rejected
    When I POST to "/internal/sessions/${completed-session-id}/pause"
    Then the response status should be 422
    And the response body path "$.error" should contain "invalid transition"

  Scenario: Session status reflects domain-level state machine
    When I GET "/internal/sessions"
    Then the response status should be 200
    And the response body path "$.sessions[*].status" should each be one of "active,paused,completed,failed"
