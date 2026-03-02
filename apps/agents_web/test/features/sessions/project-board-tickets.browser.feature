@browser @sessions
Feature: Project board tickets in the sessions sidebar
  As a delivery-focused team member
  I want the top section of the sessions sidebar to show GitHub project tickets
  So that I can pick work directly from Backlog and Ready items

  Scenario: Unauthenticated user is prompted to log in before viewing sessions
    Given I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then the URL should contain "/log-in"

  Scenario: Sessions sidebar shows project board tickets instead of top sessions
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${testEmail}"
    And I fill "#login_form_password_password" with "${testPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then I should see "Backlog"
    And I should see "Ready"
    And I should not see "Completed"
    And I should not see "Cancelled"

  Scenario: Each ticket shows key metadata in the list
    Given I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then I should see "#"
    And I should see "Title"
    And I should see "Priority"
    And I should see "Status"
    And I should see "Labels"

  Scenario: Ticket row includes associated session state when present
    Given I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then I should see "Session status"
    And I should see "No active session"

  Scenario: Ticket list refreshes when project board changes
    Given I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    When I reload the page
    And I wait for network idle
    Then I should see "Backlog"
    And I should see "Ready"

  Scenario: Opening ticket-linked work keeps session detail view functional
    Given I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    When I click the "Open" button
    And I wait for network idle
    Then I should see "Session"
    And I should see "Chat"
