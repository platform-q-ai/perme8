Feature: Layout System with HEEx Templates
  As a developer
  I want to use HEEx templates with layout inheritance
  So that I can maintain consistent styling across my site

  Background:
    Given a static site exists at "test_site"

  Scenario: Apply layout from frontmatter
    Given a post exists with frontmatter:
      """
      ---
      title: "My Post"
      layout: custom
      ---

      This is my post content.
      """
    And a layout exists at "layouts/custom.html.heex"
    When I run "mix static_site.build"
    Then the build should succeed
    And the rendered HTML should use "custom" layout

  Scenario: Apply folder-based default layout
    Given the config specifies:
      """
      defaults: %{
        post_layout: "post",
        page_layout: "page"
      }
      """
    And a layout exists at "layouts/post.html.heex"
    And a post exists at "content/posts/my-post.md" without layout specified
    When I run "mix static_site.build"
    Then the build should succeed
    And the rendered HTML should use "post" layout

  Scenario: Layout not found
    Given a post exists with frontmatter:
      """
      ---
      title: "My Post"
      layout: nonexistent
      ---

      This is my post content.
      """
    When I run "mix static_site.build"
    Then the build should fail
    And I should see error "Layout 'nonexistent' not found"
    And the error should list available layouts

  Scenario: Render partials in layout
    Given a post exists with frontmatter:
      """
      ---
      title: "Test Post"
      layout: post
      ---

      Test content.
      """
    And a layout exists at "layouts/post.html.heex" containing:
      """
      <%= render_partial("_header.html.heex", assigns) %>
      <%= @page.content %>
      """
    And a partial exists at "layouts/partials/_header.html.heex"
    When I run "mix static_site.build"
    Then the build should succeed
    And the rendered HTML should include content from the partial
