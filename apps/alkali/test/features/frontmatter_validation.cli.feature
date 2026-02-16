@cli
Feature: Frontmatter Validation
  As a developer
  I want the build to fail with clear errors when content is invalid
  So that I never deploy a broken site

  Background:
    Given I set variable "site" to "${testTmpDir}/test_site"
    When I run "rm -rf ${testTmpDir} && mix alkali.new test_site --path ${testTmpDir}"
    Then the command should succeed
    When I run "mkdir -p ${site}/content/posts"
    Then the command should succeed

  Scenario: Missing required field - title
    When I run "printf '%b' '---\ndate: 2024-01-15\n---\nContent here\n' > ${site}/content/posts/invalid.md"
    Then the command should succeed
    When I run "mix alkali.build ${site}"
    Then the command should fail
    And stderr should contain "Missing required field 'title' in content/posts/invalid.md"

  Scenario: Invalid YAML syntax
    When I run "printf '%b' '---\ntitle: Bad Post\ntags: [unterminated\n---\nContent here\n' > ${site}/content/posts/malformed.md"
    Then the command should succeed
    When I run "mix alkali.build ${site}"
    Then the command should fail
    And stderr should contain "YAML syntax error"
    And stderr should match "malformed\.md"

  Scenario: Invalid date format
    When I run "printf '%b' '---\ntitle: \"My Post\"\ndate: \"not a date\"\n---\n\nSome content here.\n' > ${site}/content/posts/bad-date.md"
    Then the command should succeed
    When I run "mix alkali.build ${site}"
    Then the command should fail
    And stderr should contain "Invalid date format, expected ISO 8601"

  Scenario: Tags field is not a list
    When I run "printf '%b' '---\ntitle: \"My Post\"\ntags: \"not-a-list\"\n---\n\nSome content here.\n' > ${site}/content/posts/bad-tags.md"
    Then the command should succeed
    When I run "mix alkali.build ${site}"
    Then the command should fail
    And stderr should contain "Tags must be a list of strings"
