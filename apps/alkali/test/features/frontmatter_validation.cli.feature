@cli
Feature: Frontmatter Validation
  As a developer
  I want the build to fail with clear errors when content is invalid
  So that I never deploy a broken site

  Background:
    Given I set working directory to "test_site"
    When I run "mkdir -p content/posts"
    Then the command should succeed

  Scenario: Missing required field - title
    When I run "printf '---\ndate: 2024-01-15\n---\nContent here\n' > content/posts/invalid.md"
    Then the command should succeed
    When I run "mix alkali.build"
    Then the command should fail
    And stderr should contain "Missing required field 'title' in content/posts/invalid.md"

  Scenario: Invalid YAML syntax
    When I run "printf '---\ntitle: Bad Post\ninvalid: yaml: [unterminated\n---\nContent here\n' > content/posts/malformed.md"
    Then the command should succeed
    When I run "mix alkali.build"
    Then the command should fail
    And stderr should contain "YAML syntax error"
    And stderr should match "malformed\\.md"
    And stderr should match "line \\d+"

  Scenario: Invalid date format
    When I run "printf '---\ntitle: \"My Post\"\ndate: \"not a date\"\n---\n\nSome content here.\n' > content/posts/bad-date.md"
    Then the command should succeed
    When I run "mix alkali.build"
    Then the command should fail
    And stderr should contain "Invalid date format, expected ISO 8601"

  Scenario: Tags field is not a list
    When I run "printf '---\ntitle: \"My Post\"\ntags: \"not-a-list\"\n---\n\nSome content here.\n' > content/posts/bad-tags.md"
    Then the command should succeed
    When I run "mix alkali.build"
    Then the command should fail
    And stderr should contain "Tags must be a list of strings"
