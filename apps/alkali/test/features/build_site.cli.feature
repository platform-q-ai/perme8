@cli
Feature: Build Static Site from Markdown
  As a developer
  I want to run a build command that generates production-ready HTML
  So that I can deploy my site to any static host

  Background:
    Given I set variable "site" to "${testTmpDir}/test_site"
    # Scaffold a full site so config, layouts, and structure exist
    When I run "rm -rf ${testTmpDir} && mix alkali.new test_site --path ${testTmpDir}"
    Then the command should succeed
    # Remove scaffolded content so each scenario starts clean
    When I run "rm -rf ${site}/content/posts/* ${site}/content/pages/* ${site}/content/index.md"
    Then the command should succeed

  Scenario: Build simple blog with posts
    # Create published posts with inline tag syntax (alkali's YAML parser requires it)
    When I run "printf '%b' '---\ntitle: First Post\ndate: 2024-01-15\ntags: [elixir, blog]\ncategory: tutorials\ndraft: false\n---\nFirst post content.\n' > ${site}/content/posts/2024-01-15-first-post.md"
    Then the command should succeed
    When I run "printf '%b' '---\ntitle: Second Post\ndate: 2024-01-16\ntags: [elixir]\ncategory: tutorials\ndraft: false\n---\nSecond post content.\n' > ${site}/content/posts/2024-01-16-second-post.md"
    Then the command should succeed
    # Create draft post
    When I run "printf '%b' '---\ntitle: Draft Post\ndate: 2024-01-17\ntags: [elixir]\ncategory: tutorials\ndraft: true\n---\nDraft post content.\n' > ${site}/content/posts/2024-01-17-draft-post.md"
    Then the command should succeed
    # Run the build
    When I run "mix alkali.build ${site}"
    Then the command should succeed
    # Verify published posts exist in the output directory (flat .html files)
    When I run "ls ${site}/_site/posts/"
    Then stdout should contain "2024-01-15-first-post.html"
    And stdout should contain "2024-01-16-second-post.html"
    # Verify draft post is NOT in the output directory
    And stdout should not contain "2024-01-17-draft-post.html"
    # Verify tag pages are generated (flat .html files)
    When I run "cat ${site}/_site/tags/elixir.html"
    Then the command should succeed
    And stdout should contain "First Post"
    And stdout should contain "Second Post"
    When I run "cat ${site}/_site/tags/blog.html"
    Then the command should succeed
    And stdout should contain "First Post"
    And stdout should not contain "Second Post"
    # Verify category pages are generated
    When I run "cat ${site}/_site/categories/tutorials.html"
    Then the command should succeed
    And stdout should contain "First Post"
    And stdout should contain "Second Post"

  Scenario: Build with drafts flag
    # Create published post
    When I run "printf '%b' '---\ntitle: Published\ndate: 2024-01-15\ndraft: false\n---\nPublished content.\n' > ${site}/content/posts/2024-01-15-published.md"
    Then the command should succeed
    # Create draft post
    When I run "printf '%b' '---\ntitle: Draft Post\ndate: 2024-01-16\ndraft: true\n---\nDraft content.\n' > ${site}/content/posts/2024-01-16-draft-post.md"
    Then the command should succeed
    # Run build with drafts flag
    When I run "mix alkali.build ${site} --draft"
    Then the command should succeed
    # Verify both published and draft posts are in output
    When I run "ls ${site}/_site/posts/"
    Then stdout should contain "2024-01-15-published.html"
    And stdout should contain "2024-01-16-draft-post.html"

  Scenario: Incremental build - only changed files
    # Create initial posts
    When I run "printf '%b' '---\ntitle: Post One\ndate: 2024-01-15\n---\nPost one content.\n' > ${site}/content/posts/2024-01-15-post-one.md"
    Then the command should succeed
    When I run "printf '%b' '---\ntitle: Post Two\ndate: 2024-01-16\n---\nPost two content.\n' > ${site}/content/posts/2024-01-16-post-two.md"
    Then the command should succeed
    # Run initial full build
    When I run "mix alkali.build ${site}"
    Then the command should succeed
    # Modify only one post (sleep to ensure different mtime)
    When I run "sleep 1 && printf '%b' '---\ntitle: Post One\ndate: 2024-01-15\n---\nPost one UPDATED content.\n' > ${site}/content/posts/2024-01-15-post-one.md"
    Then the command should succeed
    # Run incremental build
    When I run "mix alkali.build ${site}"
    Then the command should succeed
    And stdout should contain "changed"
