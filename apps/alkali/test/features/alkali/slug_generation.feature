Feature: Slug and URL Generation
  As a content creator
  I want to organize markdown files in folders that map to URL paths
  So that my site structure reflects my content hierarchy

  Background:
    Given a static site exists at "test_site"

  Scenario: Generate slug from filename
    Given a post exists at "content/posts/My First Blog Post.md"
    When I run "mix alkali.build"
    Then the build should succeed
    And the post should have URL "/posts/my-first-blog-post.html"

  Scenario: Preserve folder hierarchy in URLs
    Given a post exists at "content/posts/2024/01/my-post.md"
    When I run "mix alkali.build"
    Then the build should succeed
    And the post should have URL "/posts/2024/01/my-post.html"

  Scenario: Duplicate slugs cause build failure
    Given the following posts exist:
      | File Path                              |
      | content/posts/2024-01-15-my-post.md    |
      | content/posts/2024-01-16-my-post.md    |
    When I run "mix alkali.build"
    Then the build should fail
    And I should see error "Duplicate slug detected: 'my-post'"
    And the error should list both conflicting files

  Scenario: Remove special characters from slugs
    Given a post exists at "content/posts/Post: Part 1 (Updated!).md"
    When I run "mix alkali.build"
    Then the build should succeed
    And the post should have slug "post-part-1-updated"
