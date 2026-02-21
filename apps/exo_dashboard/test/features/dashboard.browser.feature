@browser
Feature: Dashboard Feature Tree
  As a developer using the Exo Dashboard
  I want to browse all BDD feature files in a collapsible tree
  So that I can quickly find and navigate to features and scenarios

  Scenario: Dashboard page loads with header and subtitle
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    Then I should see "Exo Dashboard"
    And I should see "BDD Feature File Explorer"

  Scenario: Dashboard displays app groups in the feature tree
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-app]" to be visible
    Then "[data-app='identity']" should exist
    And "[data-app='jarga_web']" should exist
    And "[data-app='alkali']" should exist

  Scenario: App group shows feature and scenario counts
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-app='identity']" to be visible
    Then "[data-app='identity']" should contain text "feature"
    And "[data-app='identity']" should contain text "scenario"

  Scenario: Feature tree shows features with adapter badges
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-feature]" to be visible
    Then "[data-feature='Identity Browser UI']" should exist
    And "[data-adapter='browser']" should exist

  Scenario: Filter buttons are displayed
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    Then "[data-filter='all']" should be visible
    And "[data-filter='browser']" should be visible
    And "[data-filter='http']" should be visible
    And "[data-filter='security']" should be visible
    And "[data-filter='cli']" should be visible

  Scenario: Filtering by browser adapter shows only browser features
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-app]" to be visible
    When I click "[data-filter='browser']"
    And I wait for "[data-adapter='browser']" to be visible
    Then "[data-adapter='http']" should not exist
    And "[data-adapter='cli']" should not exist

  Scenario: Filtering by HTTP adapter shows only HTTP features
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-app]" to be visible
    When I click "[data-filter='http']"
    And I wait for "[data-adapter='http']" to be visible
    Then "[data-adapter='browser']" should not exist

  Scenario: All filter resets to show all features
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-app]" to be visible
    When I click "[data-filter='browser']"
    And I wait for "[data-adapter='browser']" to be visible
    When I click "[data-filter='all']"
    And I wait for 1 seconds
    Then "[data-adapter='browser']" should exist
    And "[data-adapter='http']" should exist

  Scenario: Refresh button is present
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    Then "[data-action='refresh']" should be visible

  Scenario: Clicking a feature name navigates to feature detail
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-feature='Identity Browser UI']" to be visible
    When I click "[data-feature='Identity Browser UI'] a"
    And I wait for "#feature-detail" to be visible
    Then the URL should contain "/features/"
    And I should see "Identity Browser UI"
    And I should see "Back to dashboard"
