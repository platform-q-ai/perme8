@cli
Feature: Clean Build Output
  As a developer
  I want to clean the output directory before a fresh build
  So that I don't have stale files from previous builds

  Background:
    Given I set variable "site" to "${testTmpDir}/test_site"
    When I run "rm -rf ${testTmpDir} && mix alkali.new test_site --path ${testTmpDir}"
    Then the command should succeed

  Scenario: Clean output directory
    # Create an output directory with dummy files to simulate a previous build
    When I run "mkdir -p ${site}/_site && touch ${site}/_site/old.html ${site}/_site/stale.css"
    Then the command should succeed

    # Run the clean command
    When I run "mix alkali.clean ${site}"
    Then the command should succeed
    And stdout should contain "Output directory cleaned"

    # Verify the _site directory no longer exists
    When I run "test -d ${site}/_site && echo exists || echo removed"
    Then stdout should contain "removed"

  Scenario: Clean before build
    # Create content so the build has something to render
    When I run "mkdir -p ${site}/content/posts"
    Then the command should succeed
    When I run "printf '---\ntitle: Real Post\ndate: 2024-01-15\n---\nReal content.\n' > ${site}/content/posts/real-post.md"
    Then the command should succeed

    # Create an output directory with stale files from a previous build
    When I run "mkdir -p ${site}/_site && echo stale > ${site}/_site/stale_artifact.html"
    Then the command should succeed

    # Run build with --clean flag to remove stale output first
    When I run "mix alkali.build ${site} --clean"
    Then the command should succeed

    # Verify stale files are gone from the rebuilt output
    When I run "test -f ${site}/_site/stale_artifact.html && echo stale_found || echo stale_gone"
    Then stdout should contain "stale_gone"
    And stdout should not contain "stale_found"
