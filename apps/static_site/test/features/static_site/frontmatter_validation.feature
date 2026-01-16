Feature: Frontmatter Validation
  As a developer
  I want the build to fail with clear errors when content is invalid
  So that I never deploy a broken site

  Background:
    Given a static site exists at "test_site"

  Scenario: Missing required field - title
    Given a post exists at "content/posts/invalid.md" with content:
      """
      ---
      date: 2024-01-15
      ---
      Content here
      """
    When I run "mix static_site.build"
    Then the build should fail
    And I should see error containing:
      """
      Missing required field 'title' in content/posts/invalid.md
      """

  Scenario: Invalid YAML syntax
    Given a post exists with malformed YAML frontmatter
    When I run "mix static_site.build"
    Then the build should fail
    And I should see error "YAML syntax error"
    And the error should show the file path and line number

  Scenario: Invalid date format
    Given a post exists with frontmatter:
      """
      ---
      title: "My Post"
      date: "not a date"
      ---
      
      Some content here.
      """
    When I run "mix static_site.build"
    Then the build should fail
    And I should see error "Invalid date format, expected ISO 8601"

  Scenario: Tags field is not a list
    Given a post exists with frontmatter:
      """
      ---
      title: "My Post"
      tags: "not-a-list"
      ---
      
      Some content here.
      """
    When I run "mix static_site.build"
    Then the build should fail
    And I should see error "Tags must be a list of strings"
