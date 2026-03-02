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
    And I click the "New Session" button
    And I wait for network idle

  Scenario: Session detail view displays a tab bar
    When I wait for "[role='tablist']" to be visible
    Then "[role='tablist']" should be visible

  Scenario: Chat tab is the default active tab
    When I wait for "[role='tab'][aria-selected='true']" to be visible
    Then "[role='tab'][aria-selected='true']" should contain text "Chat"
    And "[role='tabpanel']" should be visible

  Scenario: All existing session functionality works under Chat tab
    When I wait for "[role='tab'][aria-selected='true']" to be visible
    Then "[role='tab'][aria-selected='true']" should contain text "Chat"
    And ".chat-log, [data-testid='session-output-log'], [data-testid='chat-log']" should exist
    And "form#session-form, [data-testid='instruction-form']" should exist
    And ".progress, [role='progressbar']" should exist

  Scenario: Tab bar supports dynamic tabs
    When I wait for "[role='tablist']" to be visible
    Then "[role='tab'][data-tab-id]" should exist
    And "[role='tab'][data-tab-id='chat']" should exist

  Scenario: Tab state is reflected in the URL
    Given I store the URL as "chatTabUrl"
    When I click "[role='tab']:nth-child(2)"
    And I wait for network idle
    Then the URL should contain "tab="
    And I store the URL as "otherTabUrl"
    When I go back
    And I wait for network idle
    Then the URL should be "${chatTabUrl}"
    When I go forward
    And I wait for network idle
    Then the URL should be "${otherTabUrl}"

  Scenario: Mobile responsive behaviour maintained
    When I wait for "[role='tablist']" to be visible
    Then "[role='tablist']" should be visible
    And "[role='tab'][aria-selected='true']" should be enabled
    And "[role='tabpanel']" should be visible
