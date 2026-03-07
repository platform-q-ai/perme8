@browser @sessions @search-filter
Feature: Session Search and Filtering
  As a user
  I want to search and filter sessions across both columns
  So that I can quickly find specific sessions or tickets

  # The sessions page has a unified search bar and status filter pills
  # above both the Triage and Build columns. The search input filters
  # sessions by title and tickets by title, number, and labels
  # (case-insensitive). Status filter pills filter both columns
  # simultaneously.
  #
  # NOTE: These scenarios test the UI controls and their rendering.
  # Actual filtering behaviour depends on session data which requires
  # Docker + opencode, so we focus on verifying the controls exist and
  # respond to interaction.

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  # ---------------------------------------------------------------------------
  # Search Controls
  # ---------------------------------------------------------------------------

  Scenario: Search input renders above both columns
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then "input[name='session_search']" should exist
    And "input[name='session_search'][placeholder='Search sessions and tickets...']" should exist

  Scenario: Search input accepts text
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    And I fill "input[name='session_search']" with "login"
    Then "input[name='session_search']" should exist

  # ---------------------------------------------------------------------------
  # Status Filter Pills
  # ---------------------------------------------------------------------------

  Scenario: All status filter pills are visible
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then "button[phx-click='status_filter'][phx-value-status='all']" should exist
    And "button[phx-click='status_filter'][phx-value-status='running']" should exist
    And "button[phx-click='status_filter'][phx-value-status='queued']" should exist
    And "button[phx-click='status_filter'][phx-value-status='awaiting_feedback']" should exist
    And "button[phx-click='status_filter'][phx-value-status='failed']" should exist
    And "button[phx-click='status_filter'][phx-value-status='completed']" should exist
    And "button[phx-click='status_filter'][phx-value-status='cancelled']" should exist

  Scenario: All filter is active by default
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then "button[phx-click='status_filter'][phx-value-status='all']" should have class "btn-neutral"

  Scenario: Clicking a filter pill activates it
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    And I click "button[phx-click='status_filter'][phx-value-status='running']"
    And I wait for network idle
    And I wait for "button.phx-click-loading" to be hidden
    Then "button[phx-click='status_filter'][phx-value-status='running']" should have class "btn-success"
    And "button[phx-click='status_filter'][phx-value-status='all']" should have class "btn-ghost"

  Scenario: Clicking All resets the active filter
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    And I click "button[phx-click='status_filter'][phx-value-status='failed']"
    And I wait for network idle
    And I wait for "button.phx-click-loading" to be hidden
    And I click "button[phx-click='status_filter'][phx-value-status='all']"
    And I wait for network idle
    And I wait for "button.phx-click-loading" to be hidden
    Then "button[phx-click='status_filter'][phx-value-status='all']" should have class "btn-neutral"
    And "button[phx-click='status_filter'][phx-value-status='failed']" should have class "btn-ghost"

  # ---------------------------------------------------------------------------
  # Column Structure Preserved
  # ---------------------------------------------------------------------------

  Scenario: Both Triage and Build columns remain visible with filters active
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    And I click "button[phx-click='status_filter'][phx-value-status='completed']"
    And I wait for network idle
    Then I should see "TRIAGE"
    And I should see "BUILD"
