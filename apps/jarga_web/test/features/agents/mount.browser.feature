@browser @agents
Feature: Agents UI mount verification
  As a jarga_web user
  I want to see the Agents link in the sidebar navigation
  So that I can navigate to the agents_web application

  # This is a thin mount-verification feature for jarga_web.
  # The agents UI runs as a separate app (agents_web) and is linked
  # from the jarga_web sidebar. This feature confirms the link renders
  # correctly without duplicating agents domain test coverage.

  Background:
    Given I navigate to "${baseUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  Scenario: Sidebar shows Agents link pointing to agents_web
    When I navigate to "${baseUrl}/app"
    And I wait for network idle
    Then I should see "Agents"
    And the element "a[href*='/agents']" should be visible
