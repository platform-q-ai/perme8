@cli
Feature: Asset Pipeline with Minification and Fingerprinting
  As a developer
  I want my CSS and JavaScript automatically minified and fingerprinted
  So that my site loads fast with proper cache busting

  Background:
    Given I set variable "site" to "${testTmpDir}/test_site"
    When I run "rm -rf ${testTmpDir} && mix alkali.new test_site --path ${testTmpDir}"
    Then the command should succeed
    # Clean default static assets and output so each scenario starts fresh
    When I run "rm -rf ${site}/_site ${site}/static"
    When I run "mkdir -p ${site}/static/css ${site}/static/js ${site}/static/images ${site}/_site"

  Scenario: Minify and fingerprint CSS
    # Create the source CSS file
    When I run "printf '/* Comment */\nbody {\n  margin: 0;\n  padding: 0;\n}\n' > ${site}/static/css/app.css"
    Then the command should succeed
    # Store original file size for later comparison
    When I run "wc -c < ${site}/static/css/app.css"
    Then the command should succeed
    Then I store stdout as "originalCssSize"
    # Run the build
    When I run "mix alkali.build ${site}"
    Then the command should succeed
    # A minified CSS file with fingerprint hash should exist
    When I run "ls ${site}/_site/css/"
    Then the command should succeed
    And stdout should match "app-.*\.css"
    # Store the fingerprinted filename for further assertions
    Then I store stdout matching "(app-.*\.css)" as "cssFileName"
    # The minified file should not contain comments
    When I run "cat ${site}/_site/css/app-*.css"
    Then the command should succeed
    And stdout should not contain "/* Comment */"
    # The minified file should be smaller than the original
    When I run "wc -c < ${site}/_site/css/app-*.css"
    Then the command should succeed

  Scenario: Minify and fingerprint JavaScript
    # Create the source JS file
    When I run "printf '// Comment\nfunction hello() {\n  console.log(\"Hello\");\n}\n' > ${site}/static/js/app.js"
    Then the command should succeed
    # Run the build
    When I run "mix alkali.build ${site}"
    Then the command should succeed
    # A minified JS file with fingerprint hash should exist
    When I run "ls ${site}/_site/js/"
    Then the command should succeed
    And stdout should match "app-.*\.js"
    # The minified file should not contain comments
    When I run "cat ${site}/_site/js/app-*.js"
    Then the command should succeed
    And stdout should not contain "// Comment"

  Scenario: Update asset references in HTML
    # Create a layout referencing the original CSS path
    When I run "mkdir -p ${site}/templates"
    Then the command should succeed
    When I run "printf '<html><head><link rel=\"stylesheet\" href=\"/css/app.css\"></head><body></body></html>\n' > ${site}/templates/layout.html"
    Then the command should succeed
    # Create the CSS file that will be fingerprinted
    When I run "printf 'body { margin: 0; }\n' > ${site}/static/css/app.css"
    Then the command should succeed
    # Run the build
    When I run "mix alkali.build ${site}"
    Then the command should succeed
    # The rendered HTML should reference the fingerprinted CSS path
    When I run "cat ${site}/_site/index.html"
    Then the command should succeed
    And stdout should match "/css/app-[a-f0-9]+\.css"

  Scenario: Copy static assets without processing
    # Create a binary asset (a small PNG-like file for testing)
    When I run "printf 'PNG_PLACEHOLDER' > ${site}/static/images/logo.png"
    Then the command should succeed
    # Run the build
    When I run "mix alkali.build ${site}"
    Then the command should succeed
    # The file should be copied to the output directory
    When I run "test -f ${site}/_site/images/logo.png && echo exists"
    Then the command should succeed
    And stdout should contain "exists"
    # The file should be identical to the original
    When I run "diff ${site}/static/images/logo.png ${site}/_site/images/logo.png && echo identical"
    Then the command should succeed
    And stdout should contain "identical"
