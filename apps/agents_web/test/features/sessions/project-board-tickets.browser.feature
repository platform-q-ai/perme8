@browser @sessions
Feature: Project board tickets in the sessions sidebar
  As a delivery-focused team member
  I want the sessions sidebar to include GitHub project tickets below my sessions
  So that I can see available Backlog and Ready work alongside my session history

  Background:
    Given I am logged in
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle

  Scenario: Ticket list appears below completed and cancelled sessions
    Then I should see a "Tickets" section in the sidebar
    And the "Tickets" section should appear below the sessions list
    And existing completed and cancelled sessions should still be visible above

  Scenario: Only Backlog and Ready tickets are displayed
    Then the ticket list should contain items with status "Backlog"
    And the ticket list should contain items with status "Ready"
    And the ticket list should not contain items with status "In progress"
    And the ticket list should not contain items with status "Done"

  Scenario: Each ticket shows issue number, title, priority, status, and labels
    Then each ticket card should display the issue number prefixed with "#"
    And each ticket card should display the issue title
    And each ticket card should display a priority badge
    And each ticket card should display a status badge
    And each ticket card should display any associated labels

  Scenario: Ticket card shows associated session state when a session exists
    Given a session exists that is linked to a project ticket
    Then that ticket card should show the session status indicator
    And tickets without a linked session should show no session indicator

  Scenario: Ticket list updates automatically via polling
    When new tickets are added to the project board with Backlog status
    Then the ticket list should update to include the new tickets
    And no manual page refresh should be required

  Scenario: Clicking a ticket does not break the session detail view
    When I click on a ticket in the sidebar
    Then the session detail panel should remain functional
    And the chat tab should still be accessible

  Scenario: Existing session list sections are not affected
    Then the in-progress sessions section should still appear at the bottom
    And the queue panel should still appear at the bottom
    And the quick-start form should still appear at the top
