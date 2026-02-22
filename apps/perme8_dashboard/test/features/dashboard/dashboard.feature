Feature: Perme8 Dashboard
  As a developer using the Perme8 platform
  I want a unified dashboard application that serves as the central dev-tool hub
  So that I can access the Exo BDD feature browser and future tools through a consistent tabbed interface

  Scenario: Dashboard landing page displays with tabbed navigation
    Given I navigate to the Perme8 Dashboard
    When the page loads
    Then I see a tabbed navigation layout with at least a "Features" tab
    And the "Features" tab is active by default
    And the Exo Dashboard feature list is displayed within the tab content area

  Scenario: Feature list displays app groups with feature counts
    Given I am on the Perme8 Dashboard "Features" tab
    When the features are loaded
    Then I see the same feature tree/list that was shown on the old Exo Dashboard
    And I can see app groups with their feature counts
    And I can filter features by adapter type (Browser, HTTP, Security, CLI, Graph)

  Scenario: Feature detail navigation within dashboard
    Given I am on the Perme8 Dashboard "Features" tab
    When I click on a feature in the list
    Then I navigate to the feature detail view within the Perme8 Dashboard
    And I see the feature's scenarios, steps, and tags
    And I can navigate back to the feature list

  Scenario: Exo Dashboard serves layout-less views after migration
    Given the exo_dashboard app has been migrated
    When I access the old exo_dashboard URL
    Then it should still work but without its own sidebar/topbar chrome
    And it serves as a layout-less view provider

  Scenario: Tab navigation supports extensibility
    Given the Perme8 Dashboard has a tabbed navigation
    When a new tab is added (e.g., "Sessions")
    Then the tab navigation accommodates the new tab
    And the active tab indicator moves correctly

  Scenario: Dashboard runs on configured dev port
    Given the Perme8 Dashboard is configured
    Then it runs on its own dev port (4012)
    And it is included in the dev-only app list

  Scenario: Dark theme is consistent with existing design
    Given the Perme8 Dashboard is loaded
    Then it uses the same DaisyUI dark theme as the existing exo dashboard
    And the visual design is consistent (colors, typography, spacing)
