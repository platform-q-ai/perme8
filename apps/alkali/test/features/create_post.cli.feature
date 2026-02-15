@cli
Feature: Create New Blog Post
  As a writer
  I want to create new blog posts with pre-filled frontmatter templates
  So that I don't have to remember required fields

  Background:
    Given I set working directory to "test_site"
    When I run "mkdir -p content/posts"
    Then the command should succeed

  Scenario: Create new post with title
    When I run "mix alkali.new.post 'Getting Started with Elixir'"
    Then the command should succeed
    And stdout should contain "getting-started-with-elixir.md"
    When I run "test -f content/posts/2024-01-15-getting-started-with-elixir.md && echo exists"
    Then stdout should contain "exists"
    When I run "cat content/posts/2024-01-15-getting-started-with-elixir.md"
    Then the command should succeed
    And stdout should contain "title"
    And stdout should contain "Getting Started with Elixir"
    And stdout should contain "draft"
    And stdout should contain "true"
    And stdout should contain "layout"
    And stdout should contain "post"
    And stdout should match "date"

  Scenario: Create new post with title and site path
    When I run "mix alkali.new.post 'Another Post' test_site"
    Then the command should succeed
    When I run "test -f test_site/content/posts/2024-01-15-another-post.md && echo exists"
    Then stdout should contain "exists"
    When I run "cat test_site/content/posts/2024-01-15-another-post.md"
    Then the command should succeed
    And stdout should contain "title"
    And stdout should contain "Another Post"

  Scenario: Create new post with --path option
    When I run "mix alkali.new.post 'Option Post' --path test_site"
    Then the command should succeed
    When I run "test -f test_site/content/posts/2024-01-15-option-post.md && echo exists"
    Then stdout should contain "exists"
    When I run "cat test_site/content/posts/2024-01-15-option-post.md"
    Then the command should succeed
    And stdout should contain "title"
    And stdout should contain "Option Post"

  Scenario: Short task command with site path
    When I run "mix alkali.post 'Short Post' test_site"
    Then the command should succeed
    When I run "test -f test_site/content/posts/2024-01-15-short-post.md && echo exists"
    Then stdout should contain "exists"
    When I run "cat test_site/content/posts/2024-01-15-short-post.md"
    Then the command should succeed
    And stdout should contain "title"
    And stdout should contain "Short Post"
