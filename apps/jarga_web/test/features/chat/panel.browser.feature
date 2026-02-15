@browser @chat @panel
Feature: Chat Panel Core
  As a user
  I want to open and close the global chat panel
  So that I can access AI assistance when needed without cluttering my workspace

  # Browser adapter translation of panel.feature
  # Tests core panel functionality through the browser UI:
  # - Opening/closing the panel
  # - Panel presence across pages
  # - Basic UI state management

  Background:
    Given I am on "${baseUrl}/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button
    And I wait for the page to load

  # ============================================================================
  # CRITICAL SCENARIOS
  # ============================================================================

  Scenario: Chat panel is present in admin layout
    Then "[data-test-chat-toggle]" should exist
    When I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    Then "[data-test-chat-panel]" should be visible
    And "[data-test-message-input]" should exist

  Scenario: Open chat panel displays chat interface
    When I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    Then "[data-test-agent-selector]" should be visible
    And "[data-test-message-input]" should be visible
    And "[data-test-chat-messages]" should exist

  # ============================================================================
  # HIGH PRIORITY SCENARIOS
  # ============================================================================

  Scenario: Toggle chat panel open and closed
    # Panel should be toggleable
    When I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    Then "[data-test-chat-panel]" should be visible
    When I click "[data-test-chat-close]"
    And I wait for "[data-test-chat-panel]" to be hidden
    Then "[data-test-chat-panel]" should be hidden

  # ============================================================================
  # MEDIUM PRIORITY SCENARIOS
  # ============================================================================

  Scenario: Chat panel available on all admin pages
    # Check dashboard
    Given I am on "${baseUrl}/dashboard"
    When I wait for the page to load
    Then "[data-test-chat-toggle]" should exist
    # Check workspaces
    Given I am on "${baseUrl}/workspaces"
    When I wait for the page to load
    Then "[data-test-chat-toggle]" should exist

  Scenario: Chat panel maintains state across page navigation
    When I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    # Navigate to another page
    Given I am on "${baseUrl}/workspaces"
    When I wait for the page to load
    Then "[data-test-chat-panel]" should be visible
    # Close and navigate
    When I click "[data-test-chat-close]"
    And I wait for "[data-test-chat-panel]" to be hidden
    Given I am on "${baseUrl}/dashboard"
    When I wait for the page to load
    Then "[data-test-chat-panel]" should be hidden

  Scenario: Escape key closes chat panel
    When I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    And I press "Escape"
    And I wait for "[data-test-chat-panel]" to be hidden
    Then "[data-test-chat-panel]" should be hidden

  # ============================================================================
  # LOW PRIORITY SCENARIOS
  # ============================================================================

  Scenario: Clear button disabled when chat is empty
    When I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    Then "[data-test-clear-button]" should be disabled

  Scenario: New conversation button disabled when chat is empty
    When I click "[data-test-chat-toggle]"
    And I wait for "[data-test-chat-panel]" to be visible
    Then "[data-test-new-button]" should be disabled
