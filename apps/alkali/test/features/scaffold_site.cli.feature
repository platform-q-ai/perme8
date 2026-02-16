@cli
Feature: Scaffold New Static Site
  As a developer
  I want to scaffold a new static site with example content
  So that I can start writing immediately without manual setup

  Background:
    When I run "rm -rf ${testTmpDir} && mkdir -p ${testTmpDir}"
    Then the command should succeed

  Scenario: Create new site with default structure
    When I run "mix alkali.new my_blog --path ${testTmpDir}"
    Then the command should succeed
    And I store stdout as "scaffold_output"
    # Verify success message with next steps
    And the variable "scaffold_output" should match "next steps|Next steps|Getting started|cd my_blog"
    # Verify directories were created
    When I run "ls -d ${testTmpDir}/my_blog/config"
    Then the command should succeed
    When I run "ls -d ${testTmpDir}/my_blog/content/posts"
    Then the command should succeed
    When I run "ls -d ${testTmpDir}/my_blog/content/pages"
    Then the command should succeed
    When I run "ls -d ${testTmpDir}/my_blog/layouts"
    Then the command should succeed
    When I run "ls -d ${testTmpDir}/my_blog/layouts/partials"
    Then the command should succeed
    When I run "ls -d ${testTmpDir}/my_blog/static/css"
    Then the command should succeed
    When I run "ls -d ${testTmpDir}/my_blog/static/js"
    Then the command should succeed
    When I run "ls -d ${testTmpDir}/my_blog/static/images"
    Then the command should succeed
    # Verify files were created
    When I run "test -f ${testTmpDir}/my_blog/config/alkali.exs"
    Then the command should succeed
    # Welcome post uses today's date as prefix (YYYY-MM-DD-welcome.md)
    When I run "ls ${testTmpDir}/my_blog/content/posts/"
    Then the command should succeed
    And stdout should match "welcome.md"
    When I run "test -f ${testTmpDir}/my_blog/content/pages/about.md"
    Then the command should succeed
    When I run "test -f ${testTmpDir}/my_blog/layouts/default.html.heex"
    Then the command should succeed
    When I run "test -f ${testTmpDir}/my_blog/layouts/post.html.heex"
    Then the command should succeed
    When I run "test -f ${testTmpDir}/my_blog/layouts/page.html.heex"
    Then the command should succeed
    When I run "test -f ${testTmpDir}/my_blog/static/css/app.css"
    Then the command should succeed
    When I run "test -f ${testTmpDir}/my_blog/static/js/app.js"
    Then the command should succeed

  Scenario: Prevent overwriting existing site
    When I run "mkdir -p ${testTmpDir}/my_blog"
    Then the command should succeed
    When I run "mix alkali.new my_blog --path ${testTmpDir}"
    Then the command should fail
    And stderr should contain "Directory 'my_blog' already exists"
