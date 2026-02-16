@cli
Feature: Build Static Site from Markdown
  As a developer
  I want to run a build command that generates production-ready HTML
  So that I can deploy my site to any static host

  Background:
    Given I set variable "site" to "${testTmpDir}/test_site"
    When I run "rm -rf ${testTmpDir} && mkdir -p ${site}/content/posts && mkdir -p ${site}/_site"
    Then the command should succeed
    # Create site config
    When I run "printf '%b' 'title: My Blog\nurl: https://myblog.com\nauthor: John Doe\n' > ${site}/config.yml"
    Then the command should succeed

  Scenario: Build simple blog with posts
    # Create published posts
    When I run "printf '%b' '---\ntitle: First Post\ndate: 2024-01-15\ntags:\n  - elixir\n  - blog\ncategory: tutorials\ndraft: false\n---\nFirst post content.\n' > ${site}/content/posts/2024-01-15-first-post.md"
    Then the command should succeed
    When I run "printf '%b' '---\ntitle: Second Post\ndate: 2024-01-16\ntags:\n  - elixir\ncategory: tutorials\ndraft: false\n---\nSecond post content.\n' > ${site}/content/posts/2024-01-16-second-post.md"
    Then the command should succeed
    # Create draft post
    When I run "printf '%b' '---\ntitle: Draft Post\ndate: 2024-01-17\ntags:\n  - elixir\ncategory: tutorials\ndraft: true\n---\nDraft post content.\n' > ${site}/content/posts/2024-01-17-draft-post.md"
    Then the command should succeed
    # Run the build
    When I run "mix alkali.build ${site}"
    Then the command should succeed
    # Verify published posts exist in the output directory
    When I run "ls ${site}/_site/posts/"
    Then stdout should contain "2024-01-15-first-post.html"
    And stdout should contain "2024-01-16-second-post.html"
    # Verify draft post is NOT in the output directory
    And stdout should not contain "2024-01-17-draft-post.html"
    # Verify tag pages are generated
    When I run "cat ${site}/_site/tags/elixir/index.html"
    Then the command should succeed
    And stdout should match "First Post"
    And stdout should match "Second Post"
    When I run "cat ${site}/_site/tags/blog/index.html"
    Then the command should succeed
    And stdout should contain "First Post"
    And stdout should not contain "Second Post"
    # Verify category pages are generated
    When I run "cat ${site}/_site/categories/tutorials/index.html"
    Then the command should succeed
    And stdout should contain "First Post"
    And stdout should contain "Second Post"
    # Verify build summary output
    When I run "mix alkali.build ${site}"
    Then the command should succeed
    Then I store stdout as "build_output"
    Then the variable "build_output" should contain "Parsed files"
    And the variable "build_output" should contain "3"
    And the variable "build_output" should contain "Rendered pages"
    And the variable "build_output" should contain "2"
    And the variable "build_output" should contain "Generated tag pages"
    And the variable "build_output" should contain "Generated category pages"

  Scenario: Build with drafts flag
    # Create published post
    When I run "printf '%b' '---\ntitle: Published\ndate: 2024-01-15\ndraft: false\n---\nPublished content.\n' > ${site}/content/posts/2024-01-15-published.md"
    Then the command should succeed
    # Create draft post
    When I run "printf '%b' '---\ntitle: Draft Post\ndate: 2024-01-16\ndraft: true\n---\nDraft content.\n' > ${site}/content/posts/2024-01-16-draft-post.md"
    Then the command should succeed
    # Run build with drafts flag
    When I run "mix alkali.build ${site} --drafts"
    Then the command should succeed
    # Verify both published and draft posts are in output
    When I run "ls ${site}/_site/posts/"
    Then stdout should contain "2024-01-15-published.html"
    And stdout should contain "2024-01-16-draft-post.html"
    # Verify draft posts have draft CSS class
    When I run "cat ${site}/_site/posts/2024-01-16-draft-post.html"
    Then the command should succeed
    And stdout should contain "draft"

  Scenario: Incremental build - only changed files
    # Create initial posts
    When I run "printf '%b' '---\ntitle: Post One\ndate: 2024-01-15\n---\nPost one content.\n' > ${site}/content/posts/2024-01-15-post-one.md"
    Then the command should succeed
    When I run "printf '%b' '---\ntitle: Post Two\ndate: 2024-01-16\n---\nPost two content.\n' > ${site}/content/posts/2024-01-16-post-two.md"
    Then the command should succeed
    # Run initial full build
    When I run "mix alkali.build ${site}"
    Then the command should succeed
    # Modify only one post (touch to update mtime, then rewrite content)
    When I run "sleep 1 && printf '%b' '---\ntitle: Post One\ndate: 2024-01-15\n---\nPost one UPDATED content.\n' > ${site}/content/posts/2024-01-15-post-one.md"
    Then the command should succeed
    # Run incremental build
    When I run "mix alkali.build ${site}"
    Then the command should succeed
    And stdout should contain "Rebuilt 1 file"
    And stdout should contain "1 changed"
    And stdout should contain "1 skipped"
