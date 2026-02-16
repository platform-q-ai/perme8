@cli
Feature: Layout System with HEEx Templates
  As a developer
  I want to build my site from the command line with HEEx layout templates
  So that I can verify layout resolution and rendering via CLI output

  Background:
    Given I set variable "site" to "${testTmpDir}/test_site"
    # Scaffold a fresh test site so every scenario starts from a known state
    When I run "rm -rf ${testTmpDir} && mix alkali.new test_site --path ${testTmpDir}"
    Then the command should succeed

  Scenario: Apply layout from frontmatter
    # Create a post that explicitly declares layout: custom in frontmatter
    When I run "mkdir -p ${site}/content/posts"
    Then the command should succeed
    When I run "printf '%b' '---\ntitle: My Post\ndate: 2024-01-15\nlayout: custom\n---\n\nThis is my post content.\n' > ${site}/content/posts/my-post.md"
    Then the command should succeed
    # Create the custom layout template
    When I run "printf '%b' '<!-- LAYOUT:custom -->\n<html><body><%= @content %></body></html>\n' > ${site}/layouts/custom.html.heex"
    Then the command should succeed
    # Build the site
    When I run "mix alkali.build ${site}"
    Then the command should succeed
    And stdout should contain "Build completed successfully!"
    # Verify the rendered output uses the custom layout (flat .html output)
    When I run "cat ${site}/_site/posts/my-post.html"
    Then the command should succeed
    And stdout should contain "LAYOUT:custom"
    And stdout should contain "This is my post content"

  Scenario: Apply folder-based default layout
    # The scaffolded site already has layouts; overwrite post layout with marker
    When I run "printf '%b' '<!-- LAYOUT:post -->\n<html><body><%= @content %></body></html>\n' > ${site}/layouts/post.html.heex"
    Then the command should succeed
    # Create a post WITHOUT an explicit layout in frontmatter
    When I run "mkdir -p ${site}/content/posts"
    Then the command should succeed
    When I run "printf '%b' '---\ntitle: My Post\ndate: 2024-01-15\n---\n\nFolder-based layout content.\n' > ${site}/content/posts/my-post.md"
    Then the command should succeed
    # Build the site
    When I run "mix alkali.build ${site}"
    Then the command should succeed
    And stdout should contain "Build completed successfully!"
    # Verify the rendered output uses the post layout (resolved from folder name)
    When I run "cat ${site}/_site/posts/my-post.html"
    Then the command should succeed
    And stdout should contain "LAYOUT:post"
    And stdout should contain "Folder-based layout content"

  Scenario: Layout not found
    # Remove all scaffolded content and layouts, start with only one post
    When I run "rm -rf ${site}/content ${site}/layouts"
    Then the command should succeed
    When I run "mkdir -p ${site}/content/posts ${site}/layouts"
    Then the command should succeed
    # Create a post referencing a layout that does not exist
    When I run "printf '%b' '---\ntitle: My Post\ndate: 2024-01-15\nlayout: nonexistent\n---\n\nThis is my post content.\n' > ${site}/content/posts/my-post.md"
    Then the command should succeed
    # Build the site -- should fail because layout is missing
    When I run "mix alkali.build ${site}"
    Then the command should fail
    And stderr should contain "Layout 'nonexistent' not found"

  Scenario: Render partials in layout
    # Create a post with layout: post
    When I run "mkdir -p ${site}/content/posts"
    Then the command should succeed
    When I run "printf '%b' '---\ntitle: Test Post\ndate: 2024-01-15\nlayout: post\n---\n\nTest content.\n' > ${site}/content/posts/test-post.md"
    Then the command should succeed
    # Create the post layout that includes a partial
    When I run "mkdir -p ${site}/layouts/partials"
    Then the command should succeed
    When I run "printf '%b' '<%= render_partial(\"_header.html.heex\", assigns) %>\n<main><%= @content %></main>\n' > ${site}/layouts/post.html.heex"
    Then the command should succeed
    # Create the header partial
    When I run "printf '%b' '<header><!-- PARTIAL:header -->Site Header</header>\n' > ${site}/layouts/partials/_header.html.heex"
    Then the command should succeed
    # Build the site
    When I run "mix alkali.build ${site}"
    Then the command should succeed
    And stdout should contain "Build completed successfully!"
    # Verify the rendered output includes the partial content
    When I run "cat ${site}/_site/posts/test-post.html"
    Then the command should succeed
    And stdout should contain "PARTIAL:header"
    And stdout should contain "Site Header"
    And stdout should contain "Test content"
