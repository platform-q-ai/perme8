@cli
Feature: Layout System with HEEx Templates
  As a developer
  I want to build my site from the command line with HEEx layout templates
  So that I can verify layout resolution and rendering via CLI output

  Background:
    Given I set working directory to "${TEST_SITE_DIR}"
    # Scaffold a fresh test site so every scenario starts from a known state
    When I run "mix alkali.new test_site --path ."
    Then the command should succeed
    Given I set working directory to "${TEST_SITE_DIR}/test_site"

  Scenario: Apply layout from frontmatter
    # Create a post that explicitly declares layout: custom in frontmatter
    When I run "mkdir -p content/posts"
    Then the command should succeed
    When I run "printf '---\ntitle: \"My Post\"\nlayout: custom\n---\n\nThis is my post content.\n' > content/posts/my-post.md"
    Then the command should succeed
    # Create the custom layout template
    When I run "mkdir -p layouts"
    Then the command should succeed
    When I run "printf '<!-- LAYOUT:custom -->\n<html><body><%= @content %></body></html>\n' > layouts/custom.html.heex"
    Then the command should succeed
    # Build the site
    When I run "mix alkali.build"
    Then the command should succeed
    And stdout should contain "Build completed successfully!"
    # Verify the rendered output uses the custom layout
    When I run "cat _site/posts/my-post/index.html"
    Then the command should succeed
    And stdout should contain "LAYOUT:custom"
    And stdout should contain "This is my post content"

  Scenario: Apply folder-based default layout
    # Write a config that specifies default layouts
    When I run "mkdir -p config"
    Then the command should succeed
    When I run "printf 'import Config\nconfig :alkali,\n  site: %%{title: \"Test Site\", url: \"http://localhost\", author: \"Tester\"},\n  content_path: \"content\",\n  output_path: \"_site\",\n  layouts_path: \"layouts\"\n' > config/alkali.exs"
    Then the command should succeed
    # Create the post layout (folder-based default for posts/ content)
    When I run "mkdir -p layouts"
    Then the command should succeed
    When I run "printf '<!-- LAYOUT:post -->\n<html><body><%= @content %></body></html>\n' > layouts/post.html.heex"
    Then the command should succeed
    # Create a post WITHOUT an explicit layout in frontmatter
    When I run "mkdir -p content/posts"
    Then the command should succeed
    When I run "printf '---\ntitle: \"My Post\"\n---\n\nFolder-based layout content.\n' > content/posts/my-post.md"
    Then the command should succeed
    # Build the site
    When I run "mix alkali.build"
    Then the command should succeed
    And stdout should contain "Build completed successfully!"
    # Verify the rendered output uses the post layout (resolved from folder name)
    When I run "cat _site/posts/my-post/index.html"
    Then the command should succeed
    And stdout should contain "LAYOUT:post"
    And stdout should contain "Folder-based layout content"

  Scenario: Layout not found
    # Create a post referencing a layout that does not exist
    When I run "mkdir -p content/posts"
    Then the command should succeed
    When I run "printf '---\ntitle: \"My Post\"\nlayout: nonexistent\n---\n\nThis is my post content.\n' > content/posts/my-post.md"
    Then the command should succeed
    # Remove any default layouts so resolution fails entirely
    When I run "rm -rf layouts"
    Then the command should succeed
    # Build the site -- should fail because layout is missing
    When I run "mix alkali.build"
    Then the command should fail
    And stderr should contain "Layout 'nonexistent' not found"

  Scenario: Render partials in layout
    # Create a post with layout: post
    When I run "mkdir -p content/posts"
    Then the command should succeed
    When I run "printf '---\ntitle: \"Test Post\"\nlayout: post\n---\n\nTest content.\n' > content/posts/test-post.md"
    Then the command should succeed
    # Create the post layout that includes a partial
    When I run "mkdir -p layouts/partials"
    Then the command should succeed
    When I run "printf '<%%= render_partial(\"_header.html.heex\", assigns) %%>\n<main><%%= @content %%></main>\n' > layouts/post.html.heex"
    Then the command should succeed
    # Create the header partial
    When I run "printf '<header><!-- PARTIAL:header -->Site Header</header>\n' > layouts/partials/_header.html.heex"
    Then the command should succeed
    # Build the site
    When I run "mix alkali.build"
    Then the command should succeed
    And stdout should contain "Build completed successfully!"
    # Verify the rendered output includes the partial content
    When I run "cat _site/posts/test-post/index.html"
    Then the command should succeed
    And stdout should contain "PARTIAL:header"
    And stdout should contain "Site Header"
    And stdout should contain "Test content"
