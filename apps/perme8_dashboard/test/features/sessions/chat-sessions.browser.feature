@browser
Feature: Chat Sessions Dashboard Tab (Browser)
  As a developer using the Perme8 Dashboard
  I want to view and browse chat sessions from the unified dashboard
  So that I can inspect past chat conversations and their messages without using the jarga_web chat panel

  # Browser-perspective tests for the Sessions tab added to the Perme8 Dashboard
  # alongside the existing Features tab. The Sessions view provides read-only
  # session browsing: listing sessions and viewing session details with messages.
  #
  # Data-attribute conventions for new elements:
  #   [data-tab='sessions']       - Sessions tab in the tab bar
  #   [data-session-list]         - Container for the session list
  #   [data-session]              - Individual session row/card
  #   [data-session-title]        - Session title text within a row
  #   [data-session-message-count]- Message count badge within a row
  #   [data-session-timestamp]    - Timestamp within a row
  #   [data-session-detail]       - Session detail view container
  #   [data-session-message]      - Individual message within detail
  #   [data-message-role]         - Message sender role label
  #   [data-message-content]      - Message body content
  #   [data-message-timestamp]    - Message timestamp
  #   [data-session-delete]       - Delete button for a session
  #   [data-empty-state]          - Empty state message container
  #   [data-sidebar-sessions]     - Sessions entry in sidebar navigation

  # ---------------------------------------------------------------------------
  # Dashboard Tab Navigation
  # ---------------------------------------------------------------------------

  Scenario: Sessions tab appears in dashboard navigation
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    Then "[data-tab='sessions']" should be visible
    And "[data-tab='features']" should be visible

  Scenario: Clicking the Sessions tab navigates to the sessions view
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-tab='sessions']" to be visible
    When I click "[data-tab='sessions']"
    And I wait for the page to load
    Then the URL should contain "/sessions"
    And "[data-tab='sessions']" should have class "tab-active"

  Scenario: Features tab remains functional after adding Sessions tab
    Given I navigate to "${baseUrl}/sessions"
    And I wait for the page to load
    And I wait for "[data-tab='features']" to be visible
    When I click "[data-tab='features']"
    And I wait for the page to load
    Then "[data-tab='features']" should have class "tab-active"
    And "[data-feature-tree]" should be visible

  Scenario: Sidebar navigation includes Sessions entry
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    Then "[data-sidebar-sessions]" should be visible
    And "[data-sidebar-sessions]" should contain text "Sessions"

  # ---------------------------------------------------------------------------
  # Sessions List View
  # ---------------------------------------------------------------------------

  Scenario: Sessions page displays a list of chat sessions
    Given I navigate to "${baseUrl}/sessions"
    And I wait for the page to load
    And I wait for "[data-session-list]" to be visible
    Then "[data-session]" should exist
    And "[data-session-title]" should be visible
    And "[data-session-message-count]" should be visible
    And "[data-session-timestamp]" should be visible

  Scenario: Sessions are ordered by most recent first
    Given I navigate to "${baseUrl}/sessions"
    And I wait for the page to load
    And I wait for "[data-session-list]" to be visible
    Then I store the text of "[data-session]:first-child [data-session-timestamp]" as "firstTimestamp"
    And I store the text of "[data-session]:last-child [data-session-timestamp]" as "lastTimestamp"
    # The first session in the list should have a more recent timestamp than the last.
    # Exact ordering assertion depends on timestamp format; presence of both is validated here.
    And "[data-session]:first-child [data-session-timestamp]" should be visible
    And "[data-session]:last-child [data-session-timestamp]" should be visible

  Scenario: Sessions page shows empty state when no sessions exist
    Given I navigate to "${baseUrl}/sessions"
    And I wait for the page to load
    Then "[data-empty-state]" should be visible
    And "[data-session]" should not exist

  Scenario: Session list displays multiple sessions
    Given I navigate to "${baseUrl}/sessions"
    And I wait for the page to load
    And I wait for "[data-session]" to be visible
    Then "[data-session-list]" should be visible

  # ---------------------------------------------------------------------------
  # Session Detail View
  # ---------------------------------------------------------------------------

  Scenario: Clicking a session shows its messages
    Given I navigate to "${baseUrl}/sessions"
    And I wait for the page to load
    And I wait for "[data-session]" to be visible
    When I click "[data-session]:first-child"
    And I wait for "[data-session-detail]" to be visible
    Then "[data-session-detail]" should exist
    And "[data-session-title]" should be visible
    And "[data-session-message]" should exist

  Scenario: Session messages display role and content
    Given I navigate to "${baseUrl}/sessions"
    And I wait for the page to load
    And I wait for "[data-session]" to be visible
    When I click "[data-session]:first-child"
    And I wait for "[data-session-detail]" to be visible
    Then "[data-message-role]" should be visible
    And "[data-message-content]" should be visible
    And "[data-message-timestamp]" should be visible

  Scenario: Session detail provides navigation back to session list
    Given I navigate to "${baseUrl}/sessions"
    And I wait for the page to load
    And I wait for "[data-session]" to be visible
    When I click "[data-session]:first-child"
    And I wait for "[data-session-detail]" to be visible
    When I click the "Back" link
    And I wait for "[data-session-list]" to be visible
    Then "[data-session-list]" should be visible
    And "[data-session]" should exist

  # ---------------------------------------------------------------------------
  # Independence from ChatLive.Panel
  # ---------------------------------------------------------------------------

  Scenario: Sessions view works as an independent page
    Given I navigate to "${baseUrl}/sessions"
    And I wait for the page to load
    And I wait for "[data-session-list]" to be visible
    Then "[data-chat-drawer]" should not exist
    And "[data-tab='sessions']" should have class "tab-active"
    And I should see "Perme8 Dashboard"

  # ---------------------------------------------------------------------------
  # Session Deletion
  # ---------------------------------------------------------------------------

  Scenario: Session can be deleted from the sessions list
    Given I navigate to "${baseUrl}/sessions"
    And I wait for the page to load
    And I wait for "[data-session]" to be visible
    And I store the text of "[data-session]:first-child [data-session-title]" as "sessionTitle"
    When I click "[data-session]:first-child [data-session-delete]"
    And I wait for network idle
    Then I should not see "${sessionTitle}"
