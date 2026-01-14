@chat @core
Feature: Chat Panel Core
  As a user
  I want to open and close the global chat panel
  So that I can access AI assistance when needed without cluttering my workspace

  # This file covers core panel functionality:
  # - Opening/closing the panel
  # - Panel presence across pages
  # - Basic UI state management
  # - User preference persistence

  Background:
    Given I am logged in as a user
    And I have at least one enabled agent available

  # ============================================================================
  # CRITICAL SCENARIOS
  # ============================================================================

  @critical @liveview
  Scenario: Chat panel is present in admin layout
    Given I am on any page with the admin layout
    Then I should see the chat panel component
    And the panel should contain a message input area

  @critical @liveview
  Scenario: Open chat panel displays chat interface
    Given I am on any page with the admin layout
    When I open the chat panel
    Then I should see the agent selector
    And I should see the message input field
    And I should see the chat message area

  # ============================================================================
  # HIGH PRIORITY SCENARIOS
  # ============================================================================

  @high @liveview
  Scenario: Toggle chat panel open and closed
    Given I am on any page with the admin layout
    And the chat panel is closed
    When I click the chat toggle button
    Then the chat panel should be visible
    When I click the close button
    Then the chat panel should be hidden

  @high @javascript
  Scenario: Chat panel state persists to localStorage
    Given I am on any page with the admin layout
    When I open the chat panel
    Then localStorage "chatPanelOpen" should be "true"
    When I close the chat panel
    Then localStorage "chatPanelOpen" should be "false"

  @high @liveview
  Scenario: Chat panel is accessible on desktop by default
    Given I am on desktop viewport
    And I have not set any chat panel preference
    When I navigate to the workspace overview
    Then the chat panel should be open by default

  # ============================================================================
  # MEDIUM PRIORITY SCENARIOS
  # ============================================================================

  @medium @liveview
  Scenario: Chat panel available on all admin pages
    Given I am logged in as a user
    When I visit the dashboard
    Then the chat panel toggle should be available
    When I visit a workspace overview
    Then the chat panel toggle should be available
    When I visit a document editor
    Then the chat panel toggle should be available

  @medium @liveview
  Scenario: Chat panel maintains state across page navigation
    Given the chat panel is open
    When I navigate to another page
    Then the chat panel should still be open
    When I close the chat panel
    And I navigate to another page
    Then the chat panel should still be closed

  @fix7 @medium @javascript
  Scenario: Escape key closes chat panel
    Given the chat panel is open
    When I press the Escape key
    Then the chat panel should be hidden
    And localStorage "chatPanelOpen" should be "false"

  @fix6 @medium @javascript
  Scenario: Chat panel preference preserved during viewport resize
    Given I am on desktop viewport
    And I manually close the chat panel
    When I resize to mobile viewport and back to desktop
    Then the chat panel should remain closed

  # ============================================================================
  # LOW PRIORITY SCENARIOS
  # ============================================================================

  @low @liveview
  Scenario: Clear button disabled when chat is empty
    Given the chat panel is open
    And I have no messages in the current session
    Then the "Clear" button should be disabled

  @low @liveview
  Scenario: New conversation button disabled when chat is empty
    Given the chat panel is open
    And I have no messages in the current session
    Then the "New" button should be disabled

  @fix8 @low @javascript
  Scenario: Chat panel slides from right with animation
    Given the chat panel is closed
    When I click the chat toggle button
    Then the panel should animate from the right side
    And the animation should complete within "200ms"
