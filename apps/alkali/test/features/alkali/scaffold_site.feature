Feature: Scaffold New Static Site
  As a developer
  I want to scaffold a new static site with example content
  So that I can start writing immediately without manual setup

  Scenario: Create new site with default structure
    When I run "mix alkali.new my_blog"
    Then the command should succeed
    And the following directories should be created:
      | Directory               |
      | my_blog/config          |
      | my_blog/content/posts   |
      | my_blog/content/pages   |
      | my_blog/layouts         |
      | my_blog/layouts/partials|
      | my_blog/static/css      |
      | my_blog/static/js       |
      | my_blog/static/images   |
    And the following files should be created:
      | File                                    |
      | my_blog/config/alkali.exs          |
      | my_blog/content/posts/2024-01-15-welcome.md |
      | my_blog/content/pages/about.md          |
      | my_blog/layouts/default.html.heex       |
      | my_blog/layouts/post.html.heex          |
      | my_blog/layouts/page.html.heex          |
      | my_blog/static/css/app.css              |
      | my_blog/static/js/app.js                |
    And I should see success message with next steps

  Scenario: Prevent overwriting existing site
    Given a directory "my_blog" already exists
    When I run "mix alkali.new my_blog"
    Then the command should fail
    And I should see error "Directory 'my_blog' already exists"
