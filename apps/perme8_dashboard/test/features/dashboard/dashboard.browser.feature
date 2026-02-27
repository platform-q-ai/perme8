@browser
Feature: Perme8 Dashboard Browser UI
  As a developer using the Perme8 platform
  I want a unified dashboard application that serves as the central dev-tool hub
  So that I can access the Exo BDD feature browser and future tools through a consistent tabbed interface

  Scenario: Dashboard landing page shows sidebar navigation with Features link active
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-sidebar-features]" to be visible
    Then "[data-sidebar-features]" should be visible
    And "[data-sidebar-features] a" should have class "active"

  Scenario: Features tab displays the feature tree on landing
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-sidebar-features]" to be visible
    And I wait for "[data-feature-tree]" to be visible
    Then "[data-feature-tree]" should be visible
    And I wait for "[data-app]" to be visible
    And "[data-app]" should exist

  Scenario: Feature list displays app groups with feature counts
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-app]" to be visible
    Then "[data-app]" should exist
    And I should see "feature"
    And I should see "scenario"

  Scenario: Feature list supports adapter type filtering
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-app]" to be visible
    Then "[data-filter='all']" should be visible
    And "[data-filter='browser']" should be visible
    And "[data-filter='http']" should be visible
    And "[data-filter='security']" should be visible
    And "[data-filter='cli']" should be visible

  Scenario: Filtering by adapter type shows only matching features
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-app]" to be visible
    When I click "[data-filter='browser']"
    And I wait for "[data-adapter='http']" to be hidden
    Then "[data-adapter='browser']" should exist

  Scenario: All filter resets to show every feature
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-app]" to be visible
    When I click "[data-filter='browser']"
    And I wait for "[data-adapter='http']" to be hidden
    When I click "[data-filter='all']"
    And I wait for "[data-adapter='http']" to be visible
    Then "[data-adapter='browser']" should exist

  Scenario: Clicking a feature navigates to feature detail within dashboard
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-feature]" to be visible
    When I click "[data-feature] a"
    And I wait for "[data-feature-detail]" to be visible
    Then the URL should contain "/features/"
    And I should see "Back"

  Scenario: Feature detail shows scenarios and steps
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-feature]" to be visible
    When I click "[data-feature] a"
    And I wait for "[data-feature-detail]" to be visible
    Then "[data-scenario]" should exist
    And I should see "Given"
    And I should see "Then"

  Scenario: Back navigation returns to feature list from detail
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-feature]" to be visible
    When I click "[data-feature] a"
    And I wait for "[data-feature-detail]" to be visible
    When I click the "Back" link
    And I wait for "[data-app]" to be visible
    Then "[data-feature-tree]" should be visible

  Scenario: Sidebar navigation includes Sessions link
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    Then "[data-sidebar-features]" should be visible
    And "[data-sidebar-sessions]" should be visible

  Scenario: Clicking Sessions tab redirects to login when unauthenticated
    Given I navigate to "${baseUrl}/sessions"
    And I wait for the URL to contain "/users/log-in"
    Then I should see "Log in"

  Scenario: Dashboard uses DaisyUI dark theme
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    Then "html" should have attribute "data-theme" with value "dark"
    And "body" should have class "bg-base-100"
