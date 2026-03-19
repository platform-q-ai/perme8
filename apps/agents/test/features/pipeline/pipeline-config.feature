@domain
Feature: Pipeline YAML DSL parsing and configuration
  As a platform operator
  I want to define the pipeline in a YAML file
  So that pipeline changes are version-controlled and don't require code changes

  Background:
    Given a valid perme8-pipeline.yml file exists

  Scenario: Parse a valid pipeline configuration
    When I load the pipeline configuration
    Then the pipeline config should be valid
    And the config should have a version number
    And the config should contain pipeline stages
    And each stage should have a name and description

  Scenario: Parse pipeline stages with steps
    When I load the pipeline configuration
    Then each stage should contain one or more steps
    And each step should have a name
    And steps with commands should have a command or commands list

  Scenario: Parse stage gates (entry conditions)
    Given a pipeline stage with gate conditions
    When I load the pipeline configuration
    Then the stage gate should specify required dependencies
    And the gate should have an evaluation strategy

  Scenario: Parse deploy targets
    When I load the pipeline configuration
    Then the deploy section should contain targets
    And each target should have a type and configuration

  Scenario: Parse warm-pool stage with pool configuration
    When I load the pipeline configuration
    Then the warm-pool stage should have pool settings
    And the pool should specify a target count
    And the pool should specify an image
    And the warm-pool steps should include provisioning commands

  Scenario: Parse environment variables
    When I load the pipeline configuration
    Then the config should contain environment variable definitions
    And environment variables should support variable interpolation

  Scenario: Parse change detection configuration
    When I load the pipeline configuration
    Then the config should contain change detection rules
    And each change detection rule should map paths to app names

  Scenario: Parse session configuration
    When I load the pipeline configuration
    Then the config should contain session lifecycle settings
    And session settings should include idle timeout
    And session settings should include termination triggers

  Scenario: Reject invalid YAML with missing required fields
    Given a perme8-pipeline.yml file missing the version field
    When I attempt to load the pipeline configuration
    Then the load should fail with a validation error
    And the error should identify the missing field

  Scenario: Reject invalid YAML with unknown stage type
    Given a perme8-pipeline.yml file with an invalid stage trigger type
    When I attempt to load the pipeline configuration
    Then the load should fail with a validation error
    And the error should describe the invalid value

  Scenario: Reject YAML with duplicate stage names
    Given a perme8-pipeline.yml file with duplicate stage names
    When I attempt to load the pipeline configuration
    Then the load should fail with a validation error
    And the error should identify the duplicate stage name

  Scenario: Load pipeline config entity from parsed YAML
    When I execute the LoadPipeline use case
    Then I should receive a PipelineConfig entity
    And the entity should expose stages as a list
    And the entity should expose deploy targets
    And the entity should expose session configuration
    And the entity should be queryable by stage name
