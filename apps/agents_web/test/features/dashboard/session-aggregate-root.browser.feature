@browser @sessions @aggregate-root @wip
Feature: Session aggregate root with durable interactions and ticket linking
  As a user managing agent sessions linked to tickets
  I want sessions, tasks, containers, and interactions to be durably tracked
  So that I never lose the association between a ticket and its session,
  tasks don't get lost, containers aren't orphaned, and stopping/resuming
  sessions is reliable

  # The sessions page renders session entities loaded from the sessions table
  # (a first-class aggregate root), replacing the previous GROUP BY container_id
  # aggregation. Each session owns its container metadata, lifecycle state,
  # interaction history, and task list.
  #
  # Authentication is handled via the Identity app -- the browser logs in on
  # Identity's endpoint and the session cookie (_identity_key) is shared with
  # agents_web on the same domain (localhost).

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  # ---------------------------------------------------------------------------
  # Phase 1: Session Aggregate Root -- Session List
  # ---------------------------------------------------------------------------

  Scenario: Session list displays sessions from the sessions table
    Given I navigate to "${baseUrl}/sessions?fixture=session_aggregate_list"
    And I wait for network idle
    Then "[data-testid='session-list']" should exist
    And "[data-testid='session-card']" should have at least 1 item
    And "[data-testid='session-card']:first-child [data-testid='session-title']" should be visible
    And "[data-testid='session-card']:first-child [data-testid='session-status']" should be visible

  Scenario: Session card displays container metadata
    Given I navigate to "${baseUrl}/sessions?fixture=session_aggregate_with_container"
    And I wait for network idle
    Then "[data-testid='session-card']:first-child [data-testid='container-status']" should be visible
    And "[data-testid='session-card']:first-child [data-testid='session-image']" should be visible

  Scenario: Session detail shows tasks belonging to the session
    Given I navigate to "${baseUrl}/sessions?fixture=session_aggregate_with_tasks"
    And I wait for network idle
    When I click "[data-testid='session-card']:first-child"
    And I wait for network idle
    Then "[data-testid='session-task-list']" should exist
    And "[data-testid='session-task-card']" should have at least 1 item

  Scenario: Session status reflects lifecycle state -- active
    Given I navigate to "${baseUrl}/sessions?fixture=session_aggregate_active"
    And I wait for network idle
    Then "[data-testid='session-card']:first-child [data-testid='session-status']" should have text "Active"

  Scenario: Session status reflects lifecycle state -- paused
    Given I navigate to "${baseUrl}/sessions?fixture=session_aggregate_paused"
    And I wait for network idle
    Then "[data-testid='session-card']:first-child [data-testid='session-status']" should have text "Paused"

  Scenario: Session status reflects lifecycle state -- completed
    Given I navigate to "${baseUrl}/sessions?fixture=session_aggregate_completed"
    And I wait for network idle
    Then "[data-testid='session-card']:first-child [data-testid='session-status']" should have text "Completed"

  Scenario: Session status reflects lifecycle state -- failed
    Given I navigate to "${baseUrl}/sessions?fixture=session_aggregate_failed"
    And I wait for network idle
    Then "[data-testid='session-card']:first-child [data-testid='session-status']" should have text "Failed"

  # ---------------------------------------------------------------------------
  # Phase 1: Container status displayed on session
  # ---------------------------------------------------------------------------

  Scenario: Container status pending is displayed on session card
    Given I navigate to "${baseUrl}/sessions?fixture=session_container_pending"
    And I wait for network idle
    Then "[data-testid='session-card']:first-child [data-testid='container-status']" should have text "Pending"

  Scenario: Container status running is displayed on session card
    Given I navigate to "${baseUrl}/sessions?fixture=session_container_running"
    And I wait for network idle
    Then "[data-testid='session-card']:first-child [data-testid='container-status']" should have text "Running"

  Scenario: Container status stopped is displayed on session card
    Given I navigate to "${baseUrl}/sessions?fixture=session_container_stopped"
    And I wait for network idle
    Then "[data-testid='session-card']:first-child [data-testid='container-status']" should have text "Stopped"

  # ---------------------------------------------------------------------------
  # Phase 2: Interactions -- Question/Answer History
  #
  # NOTE: Interaction records are the durable backing store for the chat log.
  # The existing session-tabs.browser.feature and queued-messages.browser.feature
  # test the chat log rendering (data-testid='chat-log'). These scenarios test
  # the structured interaction history that feeds into that chat log. The existing
  # files will be updated during Phase 2 implementation to reflect the new model.
  # ---------------------------------------------------------------------------

  Scenario: Session detail shows interaction history
    Given I navigate to "${baseUrl}/sessions?fixture=session_with_interactions"
    And I wait for network idle
    When I click "[data-testid='session-card']:first-child"
    And I wait for network idle
    Then "[data-testid='interaction-history']" should exist
    And "[data-testid='interaction-item']" should have at least 2 items

  Scenario: Pending question is displayed from interaction record
    Given I navigate to "${baseUrl}/sessions?fixture=session_with_pending_question"
    And I wait for network idle
    When I click "[data-testid='session-card']:first-child"
    And I wait for network idle
    Then "[data-testid='pending-question']" should be visible
    And "[data-testid='question-options']" should exist

  Scenario: Answering a question creates an answer interaction
    Given I navigate to "${baseUrl}/sessions?fixture=session_with_pending_question"
    And I wait for network idle
    When I click "[data-testid='session-card']:first-child"
    And I wait for network idle
    And I click "[data-testid='question-option']:first-child"
    And I wait for network idle
    Then "[data-testid='pending-question']" should not exist
    And "[data-testid='interaction-item'][data-type='answer']" should exist

  Scenario: Follow-up messages survive page reload
    Given I navigate to "${baseUrl}/sessions?fixture=session_with_queued_followups"
    And I wait for network idle
    When I click "[data-testid='session-card']:first-child"
    And I wait for network idle
    Then "[data-testid='interaction-item'][data-type='queued_response']" should exist
    When I reload the page
    And I wait for network idle
    And I click "[data-testid='session-card']:first-child"
    And I wait for network idle
    Then "[data-testid='interaction-item'][data-type='queued_response']" should exist

  Scenario: Resume instruction appears in interaction history
    Given I navigate to "${baseUrl}/sessions?fixture=session_resumed_with_interaction"
    And I wait for network idle
    When I click "[data-testid='session-card']:first-child"
    And I wait for network idle
    Then "[data-testid='interaction-item'][data-type='instruction']" should exist
    And "[data-testid='interaction-item'][data-type='instruction']" should contain text "resume"

  # ---------------------------------------------------------------------------
  # Phase 3: Ticket-Session Linking
  #
  # NOTE: These scenarios test the target state where tickets link to sessions
  # via session_id. The existing ticket-session-context.browser.feature uses
  # task_id as the linking field -- that file will be updated during Phase 3
  # implementation to reflect the migration from task_id to session_id.
  # ---------------------------------------------------------------------------

  Scenario: Starting a session from a ticket links the ticket to the session
    Given I navigate to "${baseUrl}/sessions?fixture=session_ticket_linking"
    And I wait for network idle
    Then "[data-testid='triage-ticket-item'][data-ticket-number='42'] [data-testid='ticket-session-link']" should exist
    And "[data-testid='triage-ticket-item'][data-ticket-number='42'] [data-testid='ticket-lifecycle-state']" should be visible

  Scenario: Ticket-session link survives page reload
    Given I navigate to "${baseUrl}/sessions?fixture=session_ticket_linked"
    And I wait for network idle
    Then "[data-testid='triage-ticket-item'][data-ticket-number='42'] [data-testid='ticket-session-link']" should exist
    When I reload the page
    And I wait for network idle
    Then "[data-testid='triage-ticket-item'][data-ticket-number='42'] [data-testid='ticket-session-link']" should exist

  Scenario: Clicking a linked ticket navigates to its session
    Given I navigate to "${baseUrl}/sessions?fixture=session_ticket_linked"
    And I wait for network idle
    When I click "[data-testid='triage-ticket-item'][data-ticket-number='42']"
    And I wait for network idle
    Then "[data-testid='session-detail']" should be visible
    And "[data-testid='session-title']" should be visible

  # ---------------------------------------------------------------------------
  # Phase 5: Domain-Level Session Lifecycle State Machine
  # ---------------------------------------------------------------------------

  Scenario: Pausing a session shows paused state with timestamp
    Given I navigate to "${baseUrl}/sessions?fixture=session_pause_action"
    And I wait for network idle
    When I click "[data-testid='session-card']:first-child [data-testid='pause-session-btn']"
    And I wait for network idle
    Then "[data-testid='session-card']:first-child [data-testid='session-status']" should have text "Paused"
    And "[data-testid='session-card']:first-child [data-testid='paused-at']" should be visible

  Scenario: Resuming a paused session shows active state with timestamp
    Given I navigate to "${baseUrl}/sessions?fixture=session_resume_action"
    And I wait for network idle
    When I click "[data-testid='session-card']:first-child"
    And I wait for network idle
    And I fill "[data-testid='resume-instruction-input']" with "Continue with the next step"
    And I click "[data-testid='resume-session-btn']"
    And I wait for network idle
    Then "[data-testid='session-card']:first-child [data-testid='session-status']" should have text "Active"
    And "[data-testid='session-card']:first-child [data-testid='resumed-at']" should be visible

  Scenario: Completed sessions cannot be paused
    Given I navigate to "${baseUrl}/sessions?fixture=session_aggregate_completed"
    And I wait for network idle
    Then "[data-testid='session-card']:first-child [data-testid='pause-session-btn']" should not exist
