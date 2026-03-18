@browser @analytics
Feature: Analytics Dashboard for Ticket Lifecycle Events
  As a workspace member
  I want to view analytics about ticket lifecycle events
  So that I can understand throughput, identify bottlenecks, and track cycle time trends

  # The Analytics dashboard is a new full-page view accessible from the main
  # sidebar navigation in agents_web. It displays summary counter cards, a
  # stage distribution bar chart, throughput trend line chart, and cycle time
  # trend line chart -- all scoped to the current workspace's tickets.
  #
  # Data is derived from the existing ticket lifecycle events table
  # (sessions_ticket_lifecycle_events). No new data capture is needed.
  #
  # Authentication is handled via the Identity app -- the browser logs in on
  # Identity's endpoint and the session cookie (_identity_key) is shared with
  # agents_web on the same domain (localhost).
  #
  # NOTE: This is an EARLY-PIPELINE feature file. Steps use business-language
  # descriptions. Concrete selectors and routes will be refined after the
  # architect produces an implementation plan.

  Background:
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle

  # ---------------------------------------------------------------------------
  # Navigation
  # ---------------------------------------------------------------------------

  Scenario: Analytics link is visible in the sidebar navigation
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    Then "a[href='/analytics']" should exist

  Scenario: Clicking Analytics link navigates to the analytics page
    When I navigate to "${baseUrl}/sessions"
    And I wait for network idle
    And I click "a[href='/analytics']"
    And I wait for network idle
    Then the url should contain "/analytics"

  # ---------------------------------------------------------------------------
  # Summary Counter Cards
  # ---------------------------------------------------------------------------

  Scenario: Analytics page displays summary counter cards
    When I navigate to "${baseUrl}/analytics"
    And I wait for network idle
    Then "[data-testid='summary-card-total-tickets']" should exist
    And "[data-testid='summary-card-open-tickets']" should exist
    And "[data-testid='summary-card-avg-cycle-time']" should exist
    And "[data-testid='summary-card-completed']" should exist

  # ---------------------------------------------------------------------------
  # Stage Distribution Chart
  # ---------------------------------------------------------------------------

  Scenario: Analytics page displays stage distribution bar chart
    When I navigate to "${baseUrl}/analytics"
    And I wait for network idle
    Then "[data-testid='stage-distribution-chart']" should exist
    And "[data-testid='stage-bar-open']" should exist
    And "[data-testid='stage-bar-ready']" should exist
    And "[data-testid='stage-bar-in_progress']" should exist
    And "[data-testid='stage-bar-in_review']" should exist
    And "[data-testid='stage-bar-ci_testing']" should exist
    And "[data-testid='stage-bar-deployed']" should exist
    And "[data-testid='stage-bar-closed']" should exist

  # ---------------------------------------------------------------------------
  # Trend Charts
  # ---------------------------------------------------------------------------

  Scenario: Analytics page displays throughput trend chart
    When I navigate to "${baseUrl}/analytics"
    And I wait for network idle
    Then "[data-testid='throughput-trend-chart']" should exist

  Scenario: Analytics page displays cycle time trend chart
    When I navigate to "${baseUrl}/analytics"
    And I wait for network idle
    Then "[data-testid='cycle-time-trend-chart']" should exist

  # ---------------------------------------------------------------------------
  # Time Granularity Toggle
  # ---------------------------------------------------------------------------

  Scenario: Granularity toggle options are visible
    When I navigate to "${baseUrl}/analytics"
    And I wait for network idle
    Then "[data-testid='granularity-toggle']" should exist
    And I should see "Daily"
    And I should see "Weekly"
    And I should see "Monthly"

  Scenario: Clicking Weekly granularity updates trend charts
    When I navigate to "${baseUrl}/analytics"
    And I wait for network idle
    And I click the "Weekly" button
    And I wait for network idle
    Then "[data-testid='granularity-toggle'] [aria-pressed='true']" should contain "Weekly"

  Scenario: Clicking Monthly granularity updates trend charts
    When I navigate to "${baseUrl}/analytics"
    And I wait for network idle
    And I click the "Monthly" button
    And I wait for network idle
    Then "[data-testid='granularity-toggle'] [aria-pressed='true']" should contain "Monthly"

  # ---------------------------------------------------------------------------
  # Date Range Filter
  # ---------------------------------------------------------------------------

  Scenario: Date range filter is visible with default range
    When I navigate to "${baseUrl}/analytics"
    And I wait for network idle
    Then "[data-testid='date-range-filter']" should exist
    And "[data-testid='date-range-start']" should exist
    And "[data-testid='date-range-end']" should exist

  # ---------------------------------------------------------------------------
  # Empty States
  # ---------------------------------------------------------------------------

  Scenario: Analytics page shows empty state when no lifecycle data exists
    # Uses member account which has no sessions/tickets with lifecycle events
    Given I am on "${identityUrl}/users/log-in"
    And I wait for network idle
    When I fill "#login_form_password_email" with "${memberEmail}"
    And I fill "#login_form_password_password" with "${memberPassword}"
    And I click the "Log in and stay logged in" button and wait for navigation
    And I wait for network idle
    And I navigate to "${baseUrl}/analytics"
    And I wait for network idle
    Then I should see "No lifecycle data yet"

  # ---------------------------------------------------------------------------
  # Default Date Range
  # ---------------------------------------------------------------------------

  Scenario: Analytics page loads with a default date range of last 30 days
    When I navigate to "${baseUrl}/analytics"
    And I wait for network idle
    Then "[data-testid='date-range-filter']" should exist
