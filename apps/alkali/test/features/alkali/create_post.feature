Feature: Create New Blog Post
  As a writer
  I want to create new blog posts with pre-filled frontmatter templates
  So that I don't have to remember required fields

  Background:
    Given a static site exists at "test_site"

  Scenario: Create new post with title
    When I run "mix alkali.new.post 'Getting Started with Elixir'"
    Then the command should succeed
    And a file should be created at "content/posts/2024-01-15-getting-started-with-elixir.md"
    And the file should contain frontmatter with:
      | Field       | Value                           |
      | title       | Getting Started with Elixir     |
      | draft       | true                            |
      | layout      | post                            |
    And the frontmatter should have date field with today's date
    And I should see success message showing file path

  Scenario: Create new post with title and site path
    When I run "mix alkali.new.post 'Another Post' test_site"
    Then the command should succeed
    And a file should be created at "test_site/content/posts/2024-01-15-another-post.md"
    And the file should contain frontmatter with:
      | Field       | Value                           |
      | title       | Another Post                    |

  Scenario: Create new post with --path option
    When I run "mix alkali.new.post 'Option Post' --path test_site"
    Then the command should succeed
    And a file should be created at "test_site/content/posts/2024-01-15-option-post.md"
    And the file should contain frontmatter with:
      | Field       | Value                           |
      | title       | Option Post                     |

  Scenario: Short task command with site path
    When I run "mix alkali.post 'Short Post' test_site"
    Then the command should succeed
    And a file should be created at "test_site/content/posts/2024-01-15-short-post.md"
    And the file should contain frontmatter with:
      | Field       | Value                           |
      | title       | Short Post                      |
