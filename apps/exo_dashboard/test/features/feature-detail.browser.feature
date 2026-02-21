@browser
Feature: Feature Detail View
  As a developer using the Exo Dashboard
  I want to view a single feature's scenarios and steps
  So that I can understand the BDD coverage for that feature

  Scenario: Feature detail page shows feature name and adapter badge
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-feature='Identity Browser UI']" to be visible
    When I click "[data-feature='Identity Browser UI'] a"
    And I wait for "#feature-detail" to be visible
    Then I should see "Identity Browser UI"
    And "[data-adapter='browser']" should be visible

  Scenario: Feature detail page shows scenarios as cards
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-feature='Identity Browser UI']" to be visible
    When I click "[data-feature='Identity Browser UI'] a"
    And I wait for "#feature-detail" to be visible
    Then "[data-scenario='Login page displays correctly']" should exist
    And "[data-scenario='User requests magic link via UI']" should exist

  Scenario: Scenario card shows keyword and step text
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-feature='Identity Browser UI']" to be visible
    When I click "[data-feature='Identity Browser UI'] a"
    And I wait for "[data-scenario='Login page displays correctly']" to be visible
    Then I should see "Given"
    And I should see "Then"

  Scenario: Back link returns to dashboard
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-feature='Identity Browser UI']" to be visible
    When I click "[data-feature='Identity Browser UI'] a"
    And I wait for "#feature-detail" to be visible
    Then I should see "Back to dashboard"
    When I click the "Back to dashboard" link
    And I wait for "[data-app]" to be visible
    Then I should see "Exo Dashboard"
    And the URL should be "${baseUrl}/"

  Scenario: Feature detail page has scroll-to-hash hook container
    Given I navigate to "${baseUrl}/"
    And I wait for the page to load
    And I wait for "[data-feature='Identity Browser UI']" to be visible
    When I click "[data-feature='Identity Browser UI'] a"
    And I wait for "#feature-detail" to be visible
    Then "#feature-detail" should have attribute "phx-hook" with value "ScrollToHash"

  Scenario: Feature not found shows error message
    Given I navigate to "${baseUrl}/features/nonexistent/path.feature"
    And I wait for the page to load
    And I wait for 3 seconds
    Then I should see "Feature not found"
