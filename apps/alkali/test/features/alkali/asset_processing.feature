Feature: Asset Pipeline with Minification and Fingerprinting
  As a developer
  I want my CSS and JavaScript automatically minified and fingerprinted
  So that my site loads fast with proper cache busting

  Background:
    Given a static site exists at "test_site"

  Scenario: Minify and fingerprint CSS
    Given a CSS file exists at "static/css/app.css" with content:
      """
      /* Comment */
      body {
        margin: 0;
        padding: 0;
      }
      """
    When I run "mix alkali.build"
    Then the build should succeed
    And a minified CSS file should exist at "_site/css/app-[hash].css"
    And the file should not contain comments
    And the file size should be smaller than the original

  Scenario: Minify and fingerprint JavaScript
    Given a JS file exists at "static/js/app.js" with content:
      """
      // Comment
      function hello() {
        console.log("Hello");
      }
      """
    When I run "mix alkali.build"
    Then the build should succeed
    And a minified JS file should exist at "_site/js/app-[hash].js"
    And the file should not contain comments

  Scenario: Update asset references in HTML
    Given a layout exists referencing "/css/app.css"
    And a CSS file exists at "static/css/app.css"
    When I run "mix alkali.build"
    Then the build should succeed
    And the rendered HTML should reference "/css/app-[hash].css"

  Scenario: Copy static assets without processing
    Given an image exists at "static/images/logo.png"
    When I run "mix alkali.build"
    Then the build should succeed
    And the file should be copied to "_site/images/logo.png"
    And the file should be identical to the original
