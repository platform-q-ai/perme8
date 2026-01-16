Feature: Build Static Site from Markdown
  As a developer
  I want to run a build command that generates production-ready HTML
  So that I can deploy my site to any static host

  Background:
    Given a static site exists with config:
      | Field       | Value                |
      | title       | My Blog              |
      | url         | https://myblog.com   |
      | author      | John Doe             |

  Scenario: Build simple blog with posts
    Given the following posts exist:
      | Title       | Date       | Tags         | Category  | Draft |
      | First Post  | 2024-01-15 | elixir,blog  | tutorials | false |
      | Second Post | 2024-01-16 | elixir       | tutorials | false |
      | Draft Post  | 2024-01-17 | elixir       | tutorials | true  |
    When I run "mix static_site.build"
    Then the build should succeed
    And the output directory should contain:
      | File                          |
      | _site/posts/2024-01-15-first-post.html   |
      | _site/posts/2024-01-16-second-post.html  |
    And the output directory should NOT contain:
      | File                         |
      | _site/posts/2024-01-17-draft-post.html |
    And tag pages should be generated:
      | Tag    | Post Count |
      | elixir | 2          |
      | blog   | 1          |
    And category pages should be generated:
      | Category  | Post Count |
      | tutorials | 2          |
    And I should see build summary with:
      | Metric                | Value |
      | Parsed files          | 3     |
      | Rendered pages        | 2     |
      | Generated tag pages   | 2     |
      | Generated category pages | 1  |

  Scenario: Build with drafts flag
    Given the following posts exist:
      | Title       | Date       | Draft |
      | Published   | 2024-01-15 | false |
      | Draft Post  | 2024-01-16 | true  |
    When I run "mix static_site.build --drafts"
    Then the build should succeed
    And the output directory should contain:
      | File                         |
      | _site/posts/2024-01-15-published.html  |
      | _site/posts/2024-01-16-draft-post.html |
    And draft posts should have CSS class "draft"

  Scenario: Incremental build - only changed files
    Given the following posts exist:
      | Title       | Date       |
      | Post One    | 2024-01-15 |
      | Post Two    | 2024-01-16 |
    And I have run "mix static_site.build" successfully
    And the file "content/posts/2024-01-15-post-one.md" is modified
    When I run "mix static_site.build"
    Then the build should succeed
    And only the following files should be rebuilt:
      | File                            |
      | _site/posts/2024/post-one.html  |
    And I should see "Rebuilt 1 file (1 changed, 1 skipped)"
