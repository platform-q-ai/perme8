@cli
Feature: Create New Blog Post
  As a writer
  I want to create new blog posts with pre-filled frontmatter templates
  So that I don't have to remember required fields

  Background:
    Given I set variable "site" to "${testTmpDir}/test_site"
    When I run "rm -rf ${testTmpDir} && mkdir -p ${site}/content/posts"
    Then the command should succeed

  Scenario: Create new post with title
    When I run "mix alkali.new.post 'Getting Started with Elixir' ${site}"
    Then the command should succeed
    And stdout should contain "getting-started-with-elixir.md"
    When I run "find ${site}/content/posts -name '*getting-started-with-elixir.md' | head -1 | xargs test -f && echo exists"
    Then stdout should contain "exists"
    When I run "cat ${site}/content/posts/*getting-started-with-elixir.md"
    Then the command should succeed
    And stdout should contain "title"
    And stdout should contain "Getting Started with Elixir"
    And stdout should contain "draft"
    And stdout should contain "true"
    And stdout should contain "layout"
    And stdout should contain "post"
    And stdout should match "date"

  Scenario: Create new post with title and site path
    When I run "mkdir -p ${site}/nested_site/content/posts"
    Then the command should succeed
    When I run "mix alkali.new.post 'Another Post' ${site}/nested_site"
    Then the command should succeed
    When I run "find ${site}/nested_site/content/posts -name '*another-post.md' | head -1 | xargs test -f && echo exists"
    Then stdout should contain "exists"
    When I run "cat ${site}/nested_site/content/posts/*another-post.md"
    Then the command should succeed
    And stdout should contain "title"
    And stdout should contain "Another Post"

  Scenario: Create new post with --path option
    When I run "mkdir -p ${site}/path_site/content/posts"
    Then the command should succeed
    When I run "mix alkali.new.post 'Option Post' --path ${site}/path_site"
    Then the command should succeed
    When I run "find ${site}/path_site/content/posts -name '*option-post.md' | head -1 | xargs test -f && echo exists"
    Then stdout should contain "exists"
    When I run "cat ${site}/path_site/content/posts/*option-post.md"
    Then the command should succeed
    And stdout should contain "title"
    And stdout should contain "Option Post"

  Scenario: Short task command with site path
    When I run "mkdir -p ${site}/short_site/content/posts"
    Then the command should succeed
    When I run "mix alkali.post 'Short Post' ${site}/short_site"
    Then the command should succeed
    When I run "find ${site}/short_site/content/posts -name '*short-post.md' | head -1 | xargs test -f && echo exists"
    Then stdout should contain "exists"
    When I run "cat ${site}/short_site/content/posts/*short-post.md"
    Then the command should succeed
    And stdout should contain "title"
    And stdout should contain "Short Post"
