@browser @dashboard @pipeline-kanban
Feature: Pipeline Phase 5 - Pipeline Kanban Row UI
  As a sessions dashboard user
  I want active ticket work to appear in a horizontal pipeline kanban row at the bottom of the sessions view
  So that I can understand where every ticket is in the pipeline and jump directly to the related session

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  Scenario: Sidebar layout changes
    Given I navigate to "${baseUrl}/sessions?fixture=pipeline_kanban_layout_enabled"
    And I wait for network idle
    Then I should not see "Builds"
    And I should see "Triage"
    And I should see "Pipeline"

  Scenario: Kanban columns derive from pipeline stages
    Given I navigate to "${baseUrl}/sessions?fixture=pipeline_kanban_stage_columns"
    And I wait for network idle
    Then I should see "Ready"
    And I should see "In Progress"
    And I should see "In Review"
    And I should see "CI Testing"
    And I should see "Deployed"

  Scenario: Tickets appear in their current stage
    Given I navigate to "${baseUrl}/sessions?fixture=pipeline_kanban_ticket_positions"
    And I wait for network idle
    Then I should see "#402"
    And I should see "Add pipeline kanban row"
    And I should see "In Progress"

  Scenario: Multiple tickets roll up in a stage column
    Given I navigate to "${baseUrl}/sessions?fixture=pipeline_kanban_rollup"
    And I wait for network idle
    Then I should see "In Progress"
    And I should see "4 in In Progress"
    When I click the "4 in In Progress" button
    Then I should see "#410"
    And I should see "#411"
    And I should see "#412"

  Scenario: Kanban can collapse to status bar
    Given I navigate to "${baseUrl}/sessions?fixture=pipeline_kanban_collapsible"
    And I wait for network idle
    When I click the "Expand pipeline" button
    And I wait for network idle
    Then I should see "#402"
    When I click the "Collapse pipeline" button
    And I wait for network idle
    Then I should see "Ready"
    And I should see "In Progress"
    And I should not see "#402"

  Scenario: Clicking a kanban ticket selects its session
    Given I navigate to "${baseUrl}/sessions?fixture=pipeline_kanban_ticket_to_session_selection"
    And I wait for network idle
    When I click "[data-testid='kanban-ticket-card-402']"
    And I wait for network idle
    Then I should see "Selected session: #402"

  Scenario: Live movement via PubSub
    Given I navigate to "${baseUrl}/sessions?fixture=pipeline_kanban_live_stage_change"
    And I wait for network idle
    Then I should see "#425"
    And I should see "Ready"
    When I wait for 2 seconds
    Then I should not see "#425 in Ready"
    And I should see "#425 in CI Testing"

  Scenario: Column header status summary
    Given I navigate to "${baseUrl}/sessions?fixture=pipeline_kanban_header_status_summary"
    And I wait for network idle
    Then I should see "In Review"
    And I should see "2"
    And I should see "review"
