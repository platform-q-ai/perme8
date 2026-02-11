@cli
Feature: CLI Variable Storage and Interpolation

  Scenario: Store and reuse stdout in a subsequent command
    When I run "echo captured_value"
    Then I store stdout as "output"
    When I run "echo got: ${output}"
    Then stdout should contain "got: captured_value"

  Scenario: Store exit code as variable
    When I run "exit 5"
    Then I store exit code as "code"

  Scenario: Store stderr as variable
    When I run "echo err_content >&2"
    Then I store stderr as "error_output"

  Scenario: Store a specific stdout line
    When I run "printf 'first\nsecond\nthird\n'"
    Then I store stdout line 2 as "second_line"
    When I run "echo ${second_line}"
    Then stdout should contain "second"

  Scenario: Store stdout matching a regex
    When I run "echo version 3.14.1"
    Then I store stdout matching "version (.*)" as "ver"
    When I run "echo ${ver}"
    Then stdout should contain "3.14.1"
