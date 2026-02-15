@cli
Feature: Slug and URL Generation
  As a content creator
  I want to organize markdown files in folders that map to URL paths
  So that my site structure reflects my content hierarchy

  Background:
    Given I set variable "site" to "${testTmpDir}/test_site"
    When I run "rm -rf ${testTmpDir} && mix alkali.new test_site --path ${testTmpDir}"
    Then the command should succeed

  Scenario: Generate slug from filename
    When I run "mkdir -p ${site}/content/posts && printf '---\ntitle: My First Blog Post\n---\nHello world\n' > '${site}/content/posts/My First Blog Post.md'"
    Then the command should succeed
    When I run "mix alkali.build ${site}"
    Then the command should succeed
    And stdout should contain "Build completed successfully!"
    When I run "ls ${site}/_site/posts/my-first-blog-post.html"
    Then the command should succeed
    And stdout should contain "my-first-blog-post.html"

  Scenario: Preserve folder hierarchy in URLs
    When I run "mkdir -p ${site}/content/posts/2024/01 && printf '---\ntitle: My Post\n---\nContent here\n' > ${site}/content/posts/2024/01/my-post.md"
    Then the command should succeed
    When I run "mix alkali.build ${site}"
    Then the command should succeed
    And stdout should contain "Build completed successfully!"
    When I run "ls ${site}/_site/posts/2024/01/my-post.html"
    Then the command should succeed
    And stdout should contain "my-post.html"

  Scenario: Duplicate slugs cause build failure
    When I run "mkdir -p ${site}/content/posts && printf '---\ntitle: My Post\ndate: 2024-01-15\n---\nFirst post\n' > ${site}/content/posts/2024-01-15-my-post.md && printf '---\ntitle: My Post\ndate: 2024-01-16\n---\nSecond post\n' > ${site}/content/posts/2024-01-16-my-post.md"
    Then the command should succeed
    When I run "mix alkali.build ${site}"
    Then the command should fail
    And stderr should contain "Duplicate slug detected: 'my-post'"
    And stderr should contain "2024-01-15-my-post.md"
    And stderr should contain "2024-01-16-my-post.md"

  Scenario: Remove special characters from slugs
    When I run "mkdir -p ${site}/content/posts && printf '---\ntitle: Post Part 1 Updated\n---\nContent\n' > '${site}/content/posts/Post: Part 1 (Updated!).md'"
    Then the command should succeed
    When I run "mix alkali.build ${site}"
    Then the command should succeed
    And stdout should contain "Build completed successfully!"
    When I run "ls ${site}/_site/posts/post-part-1-updated.html"
    Then the command should succeed
    And stdout should contain "post-part-1-updated"
