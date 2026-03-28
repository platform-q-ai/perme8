@browser @sessions
Feature: Session Detail Tabbed Layout
  As a user
  I want the session detail panel to use a tabbed layout
  So that I can navigate between different views of a session (starting with Chat)

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    And I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    And I click "[phx-click='select_ticket'][phx-value-number='101']"
    And I wait for network idle

  Scenario: Session detail view displays a tab bar
    When I wait for "[role='tablist']" to be visible
    Then "[role='tablist']" should be visible

  # Chat-tab default/browser interaction scenarios are temporarily disabled.
  # URL and tab-bar behaviour remain covered below and in LiveView tests.

  Scenario: Tab bar supports dynamic tabs
    When I wait for "[role='tablist']" to be visible
    Then "[role='tab'][data-tab-id]" should exist
    And "[role='tab'][data-tab-id='chat']" should exist

  Scenario: Tab state is reflected in the URL
    Given I store the URL as "ticketTabUrl"
    When I click "[role='tab'][data-tab-id='chat']"
    And I wait for network idle
    Then the URL should contain "tab="
    When I go back
    And I wait for network idle
    Then the URL should be "${ticketTabUrl}"

  Scenario: Mobile responsive behaviour maintained
    When I wait for "[role='tablist']" to be visible
    Then "[role='tablist']" should be visible
    And "[role='tab'][aria-selected='true']" should be enabled
    And "[role='tabpanel']" should be visible
