@browser @sessions @ticket-dependencies @wip
Feature: Ticket dependency management (blocks/blocked-by) in Sessions dashboard
  As a developer using the Sessions UI
  I want to add and remove directional dependency relationships between tickets
  So that I can track work sequencing, see which tickets are blocked, and avoid starting blocked work

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle

  # Dependency Display in Detail Panel

  Scenario: Ticket detail panel shows "Blocked by" section with dependencies
    Given a ticket is blocked by another ticket
    When I click on the blocked ticket in the triage sidebar
    And I wait for network idle
    Then I should see "Blocked by"
    And I should see the blocking ticket listed as a clickable link in the "Blocked by" section

  Scenario: Ticket detail panel shows "Blocks" section with dependencies
    Given a ticket blocks another ticket
    When I click on the blocking ticket in the triage sidebar
    And I wait for network idle
    Then I should see "Blocks"
    And I should see the blocked ticket listed as a clickable link in the "Blocks" section

  Scenario: Ticket with no dependencies shows no dependency sections
    Given a ticket has no dependencies
    When I click on that ticket in the triage sidebar
    And I wait for network idle
    Then I should not see "Blocked by"
    And I should not see "Blocks"

  # Adding Dependencies via Searchable Typeahead

  Scenario: Adding a "blocked by" dependency via typeahead search
    When I click on a ticket in the triage sidebar
    And I wait for network idle
    And I click the "Add dependency" button in the detail panel
    Then a searchable typeahead input should appear
    When I type a partial ticket title into the typeahead
    Then matching tickets should appear as suggestions
    When I select a suggested ticket
    And I choose "blocked by" as the dependency direction
    Then the dependency is saved
    And the "Blocked by" section shows the newly added dependency

  Scenario: Adding a "blocks" dependency via typeahead search
    When I click on a ticket in the triage sidebar
    And I wait for network idle
    And I click the "Add dependency" button in the detail panel
    And I type a ticket number into the typeahead
    Then matching tickets should appear as suggestions
    When I select a suggested ticket
    And I choose "blocks" as the dependency direction
    Then the dependency is saved
    And the "Blocks" section shows the newly added dependency

  Scenario: Current ticket is excluded from typeahead search results
    When I click on a ticket in the triage sidebar
    And I wait for network idle
    And I click the "Add dependency" button in the detail panel
    And I type the current ticket's title into the typeahead
    Then the current ticket should not appear in the search results

  # Removing Dependencies

  Scenario: Removing a "blocked by" dependency
    Given ticket A is blocked by ticket B
    When I click on ticket A in the triage sidebar
    And I wait for network idle
    And I click the remove action next to ticket B in the "Blocked by" section
    Then the dependency is removed
    And ticket B no longer appears in the "Blocked by" section

  Scenario: Removing a "blocks" dependency
    Given ticket A blocks ticket C
    When I click on ticket A in the triage sidebar
    And I wait for network idle
    And I click the remove action next to ticket C in the "Blocks" section
    Then the dependency is removed
    And ticket C no longer appears in the "Blocks" section

  # Navigation via Dependency Links

  Scenario: Clicking a dependency navigates to that ticket's detail
    Given ticket A is blocked by ticket B
    When I click on ticket A in the triage sidebar
    And I wait for network idle
    And I click on ticket B in the "Blocked by" section
    Then the detail panel navigates to show ticket B's details

  # Sidebar Blocked Indicator

  Scenario: Blocked ticket shows indicator on triage sidebar card
    Given ticket A has an unresolved "blocked by" dependency on an open ticket
    Then ticket A's card in the triage sidebar displays a "Blocked" indicator

  Scenario: Blocked indicator shows "actively blocked" when blockers are open
    Given ticket A is blocked by ticket B which is open
    Then ticket A's sidebar card shows an "actively blocked" indicator

  Scenario: Blocked indicator shows "resolved" when all blockers are closed
    Given ticket A is blocked by ticket B which is closed
    Then ticket A's sidebar card shows a "resolved" blocked indicator

  Scenario: Unblocked ticket shows no blocked indicator
    Given ticket A has no "blocked by" dependencies
    Then ticket A's card in the triage sidebar does not display a blocked indicator

  # Session Start Gating

  Scenario: Starting a session on an actively blocked ticket is prevented
    Given ticket A is actively blocked by open ticket B
    When I attempt to start a session on ticket A
    Then the start session action is disabled for ticket A
    And a message explains that ticket A is blocked by ticket B

  Scenario: Starting a session on an unblocked ticket works normally
    Given ticket A has no active blocking dependencies
    When I start a session on ticket A
    Then the session starts normally

  Scenario: Starting a session becomes available when blockers are resolved
    Given ticket A was blocked by ticket B
    And ticket B is now closed
    When I view ticket A in the triage sidebar
    Then the start session action is enabled for ticket A

  # Validation and Error Handling

  Scenario: Circular dependency is prevented with error message
    Given ticket A blocks ticket B
    When I view ticket B's detail panel
    And I try to add ticket A as a "blocked by" dependency of ticket B
    Then the system rejects the dependency with a circular dependency error message

  Scenario: Duplicate dependency is prevented with message
    Given ticket A is already blocked by ticket B
    When I try to add ticket B as a "blocked by" dependency of ticket A again
    Then a message indicates the dependency already exists

  # Filtering by Blocked Status

  Scenario: Filter triage sidebar to show all tickets (default)
    When I set the blocked status filter to "All"
    Then all tickets are visible in the triage sidebar

  Scenario: Filter triage sidebar to show only unblocked tickets
    Given some tickets are blocked and some are not
    When I set the blocked status filter to "Unblocked"
    Then only tickets without active blockers are visible in the triage sidebar

  Scenario: Filter triage sidebar to show only blocked tickets
    Given some tickets are blocked and some are not
    When I set the blocked status filter to "Blocked"
    Then only tickets with active blockers are visible in the triage sidebar

  # Sync Resilience and Real-Time Updates

  Scenario: Dependencies survive a GitHub sync cycle
    Given ticket A is blocked by ticket B (local dependency)
    When a GitHub sync completes
    Then the dependency between ticket A and ticket B still exists
    And the blocked indicator remains visible on ticket A's sidebar card

  Scenario: Dependency changes update in real-time without page reload
    Given I am viewing ticket A's detail panel
    When a new "blocked by" dependency is added to ticket A
    Then the "Blocked by" section updates automatically without a page reload
