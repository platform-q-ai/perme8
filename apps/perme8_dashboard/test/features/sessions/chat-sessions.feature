Feature: Chat Sessions Dashboard Tab
  As a developer using the Perme8 Dashboard
  I want to view and browse chat sessions from the unified dashboard
  So that I can inspect past chat conversations and their messages without using the jarga_web chat panel

  # The Sessions tab is added to the Perme8 Dashboard alongside the existing
  # Features tab. It renders a standalone Sessions view that lists all chat
  # sessions from the Jarga.Chat context.
  #
  # The Sessions view is decoupled from the ChatLive.Panel drawer in jarga_web.
  # It provides read-only session browsing: listing sessions and viewing
  # session details with messages.
  #
  # The domain layer (Jarga.Chat) remains in the jarga app. Only the
  # presentation layer lives in agents_web / perme8_dashboard.

  # ---------------------------------------------------------------------------
  # Dashboard Tab Navigation
  # ---------------------------------------------------------------------------

  Scenario: Sessions tab appears in dashboard navigation
    Given I am on the Perme8 Dashboard
    Then I should see a "Sessions" tab in the tab bar
    And I should see a "Features" tab in the tab bar

  Scenario: Clicking the Sessions tab navigates to the sessions view
    Given I am on the Perme8 Dashboard
    When I click the "Sessions" tab
    Then I should be on the sessions page
    And the Sessions tab should be active

  Scenario: Features tab remains functional after adding Sessions tab
    Given I am on the sessions page of the Perme8 Dashboard
    When I click the "Features" tab
    Then I should be on the features page
    And the Features tab should be active

  Scenario: Sidebar navigation includes Sessions entry
    Given I am on the Perme8 Dashboard
    Then the sidebar should include a "Sessions" navigation link

  # ---------------------------------------------------------------------------
  # Sessions List View
  # ---------------------------------------------------------------------------

  Scenario: Sessions page displays a list of chat sessions
    Given I am on the sessions page of the Perme8 Dashboard
    Then I should see a list of chat sessions
    And each session should display its title
    And each session should display a message count
    And each session should display a timestamp

  Scenario: Sessions are ordered by most recent first
    Given I am on the sessions page of the Perme8 Dashboard
    And there are multiple chat sessions
    Then the sessions should be ordered with the most recent first

  Scenario: Sessions page shows empty state when no sessions exist
    Given I am on the sessions page of the Perme8 Dashboard
    And there are no chat sessions
    Then I should see a message indicating no sessions exist

  # ---------------------------------------------------------------------------
  # Session Detail View
  # ---------------------------------------------------------------------------

  Scenario: Clicking a session shows its messages
    Given I am on the sessions page of the Perme8 Dashboard
    And there is a session with messages
    When I click on a session
    Then I should see the session detail view
    And I should see the session title
    And I should see the messages in the session

  Scenario: Session messages display role and content
    Given I am viewing a session detail
    Then each message should display the sender role
    And each message should display the message content
    And each message should display a timestamp

  Scenario: Session detail provides navigation back to session list
    Given I am viewing a session detail
    When I navigate back to the session list
    Then I should see the list of chat sessions

  # ---------------------------------------------------------------------------
  # Independence from ChatLive.Panel
  # ---------------------------------------------------------------------------

  Scenario: Sessions view works as an independent page
    Given I am on the sessions page of the Perme8 Dashboard
    Then the page should render without the ChatLive.Panel drawer
    And the sessions view should be standalone within the dashboard layout

  # ---------------------------------------------------------------------------
  # Session Deletion
  # ---------------------------------------------------------------------------

  Scenario: Session can be deleted from the sessions list
    Given I am on the sessions page of the Perme8 Dashboard
    And there is at least one chat session
    When I delete a session
    Then the session should be removed from the list
