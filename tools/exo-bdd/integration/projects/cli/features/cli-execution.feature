@cli
Feature: CLI Command Execution

  Scenario: Run a simple echo command
    When I run "echo hello world"
    Then the command should succeed
    And stdout should contain "hello world"

  Scenario: Run a failing command
    When I run "exit 1"
    Then the command should fail
    And the exit code should be 1

  Scenario: Run a command with inline stdin
    When I run "cat" with stdin "piped input"
    Then the command should succeed
    And stdout should contain "piped input"

  Scenario: Run a command with multiline stdin
    When I run "cat" with stdin:
      """
      line one
      line two
      """
    Then stdout should contain "line one"
    And stdout should contain "line two"
