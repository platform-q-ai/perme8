@cli
Feature: CLI Environment Variables

  Scenario: Set and use an environment variable
    Given I set environment variable "MY_VAR" to "test_value"
    When I run "echo $MY_VAR"
    Then stdout should contain "test_value"

  Scenario: Override an environment variable
    Given I set environment variable "OVERRIDE_ME" to "first"
    Given I set environment variable "OVERRIDE_ME" to "second"
    When I run "echo $OVERRIDE_ME"
    Then stdout should contain "second"

  Scenario: Clear an environment variable
    Given I set environment variable "TEMP_VAR" to "exists"
    Given I clear environment variable "TEMP_VAR"
    When I run "echo ${TEMP_VAR:-unset}"
    Then stdout should contain "unset"

  Scenario: Set working directory
    Given I set working directory to "/tmp"
    When I run "pwd"
    Then stdout should contain "/tmp"
