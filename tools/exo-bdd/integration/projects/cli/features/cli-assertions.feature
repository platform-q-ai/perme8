@cli
Feature: CLI Output Assertions

  Scenario: Assert specific exit code
    When I run "exit 42"
    Then the exit code should be 42
    And the exit code should not be 0

  Scenario: Assert stdout matches regex
    When I run "echo version 1.2.3"
    Then stdout should match "version \d+\.\d+\.\d+"

  Scenario: Assert stderr content
    When I run "echo error message >&2"
    Then stderr should contain "error message"

  Scenario: Assert stdout line by line
    When I run "printf 'alpha\nbeta\ngamma\n'"
    Then stdout line 1 should equal "alpha"
    Then stdout line 2 should contain "bet"
    Then stdout line 3 should equal "gamma"

  Scenario: Assert empty stdout and stderr
    When I run "true"
    Then stdout should be empty
    And stderr should be empty

  Scenario: Assert stdout does not contain
    When I run "echo hello"
    Then stdout should not contain "goodbye"

  Scenario: Assert stdout exact match
    When I run "echo exact output"
    Then stdout should equal:
      """
      exact output
      """
