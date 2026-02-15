@cli
Feature: Clean Build Output
  As a developer
  I want to clean the output directory before a fresh build
  So that I don't have stale files from previous builds

  Background:
    Given I set working directory to "test_site"
    When I run "mkdir -p test_site && cp -r test/fixtures/site/* test_site/ 2>/dev/null || true"
    Then the command should succeed

  Scenario: Clean output directory
    # Create an output directory with dummy files to simulate a previous build
    When I run "mkdir -p _site && touch _site/old.html _site/stale.css"
    Then the command should succeed

    # Run the clean command
    When I run "mix alkali.clean"
    Then the command should succeed
    And stdout should contain "Output directory cleaned"

    # Verify the _site directory no longer exists
    When I run "test -d _site && echo exists || echo removed"
    Then stdout should contain "removed"

  Scenario: Clean before build
    # Create an output directory with stale files from a previous build
    When I run "mkdir -p _site && echo stale > _site/stale_artifact.html"
    Then the command should succeed

    # Run build with --clean flag to remove stale output first
    When I run "mix alkali.build --clean"
    Then the command should succeed

    # Verify stale files are gone from the rebuilt output
    When I run "test -f _site/stale_artifact.html && echo stale_found || echo stale_gone"
    Then stdout should contain "stale_gone"
    And stdout should not contain "stale_found"
