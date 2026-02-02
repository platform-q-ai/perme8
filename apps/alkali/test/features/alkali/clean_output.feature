Feature: Clean Build Output
  As a developer
  I want to clean the output directory before a fresh build
  So that I don't have stale files from previous builds

  Background:
    Given a static site exists at "test_site"

  Scenario: Clean output directory
    Given the output directory "_site" exists with files
    When I run "mix alkali.clean"
    Then the command should succeed
    And the directory "_site" should not exist
    And I should see success message "Output directory cleaned"

  Scenario: Clean before build
    Given the output directory "_site" exists with stale files
    When I run "mix alkali.build --clean"
    Then the build should succeed
    And the output should not contain stale files
