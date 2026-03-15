@browser @sessions @ticket-dependencies @wip
Feature: Ticket dependency management (blocks/blocked-by) in Sessions
  As a developer using the Sessions UI
  I want to manage directional dependency relationships between tickets
  So that I can track sequencing dependencies, avoid starting work on blocked tickets, and focus on unblocked work first

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle

  # --- Adding Dependencies ---

  Scenario: Adding a "blocks" dependency from the ticket detail panel
    When I click "#triage-lane [data-testid^='triage-ticket-item-']"
    And I wait for network idle
    Then "[data-testid='ticket-detail-panel']" should be visible
    When I click "[data-testid='add-dependency-button']"
    Then "[data-testid='dependency-search-input']" should be visible
    When I fill "[data-testid='dependency-search-input']" with a target ticket number
    And I wait for network idle
    And I click "[data-testid='dependency-search-result']:first-child"
    And I click "[data-testid='dependency-direction-blocks']"
    And I click "[data-testid='dependency-confirm-button']"
    Then "[data-testid='ticket-blocks-section']" should be visible
    And I should see the target ticket in the Blocks list
    And "[data-testid='ticket-blocks-section'] a" should exist

  Scenario: Adding a "blocked by" dependency from the ticket detail panel
    When I click "#triage-lane [data-testid^='triage-ticket-item-']"
    And I wait for network idle
    Then "[data-testid='ticket-detail-panel']" should be visible
    When I click "[data-testid='add-dependency-button']"
    And I fill "[data-testid='dependency-search-input']" with a blocking ticket number
    And I wait for network idle
    And I click "[data-testid='dependency-search-result']:first-child"
    And I click "[data-testid='dependency-direction-blocked-by']"
    And I click "[data-testid='dependency-confirm-button']"
    Then "[data-testid='ticket-blocked-by-section']" should be visible
    And I should see the blocking ticket in the Blocked by list
    And "[data-testid='ticket-blocked-by-section'] a" should exist

  # --- Searching for Tickets ---

  Scenario: Searching for tickets when adding a dependency via typeahead
    When I click "#triage-lane [data-testid^='triage-ticket-item-']"
    And I wait for network idle
    And I click "[data-testid='add-dependency-button']"
    When I fill "[data-testid='dependency-search-input']" with a partial ticket title
    And I wait for network idle
    Then "[data-testid='dependency-search-results']" should be visible
    And "[data-testid='dependency-search-result']" should exist

  Scenario: Current ticket is excluded from dependency search results
    When I click "#triage-lane [data-testid^='triage-ticket-item-']"
    And I wait for network idle
    And I click "[data-testid='add-dependency-button']"
    When I fill "[data-testid='dependency-search-input']" with the current ticket number
    And I wait for network idle
    Then the current ticket should not appear in the search results

  # --- Removing Dependencies ---

  Scenario: Removing an existing dependency from the detail panel
    # Precondition: ticket has an existing dependency
    When I click "#triage-lane [data-testid^='triage-ticket-item-']"
    And I wait for network idle
    Then "[data-testid='ticket-blocks-section']" should be visible
    When I click "[data-testid='remove-dependency-button']:first-child"
    Then the dependency is removed from the list
    And the detail panel updates immediately

  # --- Blocked Indicators on Sidebar Cards ---

  Scenario: Blocked tickets display a visual indicator on sidebar cards
    # Precondition: a ticket with unresolved blocked-by dependencies exists
    Then "#triage-lane [data-testid^='triage-ticket-item-'][data-blocked='true'] [data-testid='blocked-indicator']" should exist

  Scenario: Blocked indicator distinguishes actively blocked from all-resolved
    # Actively blocked: at least one open blocker
    Then "#triage-lane [data-testid^='triage-ticket-item-'][data-blocked='active'] [data-testid='blocked-indicator']" should exist
    # All blockers resolved (closed)
    And "#triage-lane [data-testid^='triage-ticket-item-'][data-blocked='resolved'] [data-testid='blocked-indicator']" should exist

  Scenario: Blocked ticket shows count badge of open blockers
    # Precondition: a ticket blocked by 2 open tickets
    Then I should see "Blocked by 2"

  # --- Circular and Duplicate Dependency Prevention ---

  Scenario: Circular dependency is prevented with error message
    # Precondition: ticket A blocks ticket B
    When I click the ticket B card in the triage sidebar
    And I wait for network idle
    And I click "[data-testid='add-dependency-button']"
    And I fill "[data-testid='dependency-search-input']" with ticket A number
    And I wait for network idle
    And I click "[data-testid='dependency-search-result']:first-child"
    And I click "[data-testid='dependency-direction-blocks']"
    And I click "[data-testid='dependency-confirm-button']"
    Then I should see "Cannot add this dependency"
    And I should see "circular"

  Scenario: Duplicate dependency is prevented with user message
    # Precondition: dependency already exists between two tickets
    When I click a ticket card that already has a dependency
    And I wait for network idle
    And I click "[data-testid='add-dependency-button']"
    And I attempt to add the same dependency again
    Then I should see "already exists"

  # --- Session Start Prevention ---

  Scenario: Starting a session on a blocked ticket is prevented
    # Precondition: a ticket is actively blocked by open tickets
    When I click "#triage-lane [data-testid^='triage-ticket-item-'][data-blocked='active']"
    And I wait for network idle
    Then "[data-testid='start-ticket-session-button']" should not exist
    And I should see "Blocked by"
    And "[data-testid='blocker-ticket-link']" should exist

  # --- Filtering by Blocked Status ---

  Scenario: Filtering triage sidebar to show only blocked tickets
    When I click "[data-testid='filter-blocked-only']"
    And I wait for network idle
    Then "#triage-lane [data-testid^='triage-ticket-item-'][data-blocked='active']" should exist
    And "#triage-lane [data-testid^='triage-ticket-item-']:not([data-blocked])" should not exist

  Scenario: Filtering triage sidebar to show only unblocked tickets
    When I click "[data-testid='filter-unblocked-only']"
    And I wait for network idle
    Then "#triage-lane [data-testid^='triage-ticket-item-']:not([data-blocked])" should exist
    And "#triage-lane [data-testid^='triage-ticket-item-'][data-blocked='active']" should not exist

  Scenario: Filtering triage sidebar to show all tickets
    When I click "[data-testid='filter-all']"
    And I wait for network idle
    Then "#triage-lane [data-testid^='triage-ticket-item-']" should exist

  # --- Ticket Detail Panel Sections ---

  Scenario: Ticket detail shows both Blocks and Blocked-by sections
    # Precondition: ticket blocks some tickets and is blocked by others
    When I click a ticket that has both types of dependencies
    And I wait for network idle
    Then "[data-testid='ticket-blocks-section']" should be visible
    And "[data-testid='ticket-blocked-by-section']" should be visible
    And "[data-testid='ticket-blocks-section'] a" should exist
    And "[data-testid='ticket-blocked-by-section'] a" should exist

  Scenario: Clicking a dependency ticket navigates to its detail
    When I click a ticket with dependencies in the triage sidebar
    And I wait for network idle
    And I click "[data-testid='ticket-blocks-section'] a:first-child"
    Then "[data-testid='ticket-detail-panel']" should be visible

  # --- Sync Resilience ---

  Scenario: Dependencies survive a GitHub sync cycle
    # Precondition: tickets have dependency relationships
    When I click the "Sync tickets" button
    And I wait for network idle
    Then "[data-testid='ticket-blocks-section']" should be visible
    And the previously set dependencies are still present

  Scenario: Blocker ticket closed updates blocked indicator automatically
    # Precondition: ticket A is blocked by ticket B
    # When ticket B is closed (via sync or manually)
    When I click the "Sync tickets" button
    And I wait for network idle
    Then the blocked indicator on ticket A reflects the resolved state
