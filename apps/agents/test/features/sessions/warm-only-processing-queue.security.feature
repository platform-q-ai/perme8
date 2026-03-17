Feature: Secure warm-start preparation for fresh containers
  As a platform operator
  I want fresh warm containers to prepare repos and auth before first task start
  So execution begins from current code and valid credentials

  Scenario: Fresh warm container performs repo update before first start
    Given a queued task is assigned a fresh warm container
    And the container has never run task execution
    When the task is started
    Then all configured repositories are updated before prompt execution begins

  Scenario: Fresh warm container refreshes auth tokens before first start
    Given a queued task is assigned a fresh warm container
    And the container has never run task execution
    When the task is started
    Then auth token refresh runs before prompt execution begins

  Scenario: Warm-start preparation is first-start only
    Given a container already completed first-start preparation
    When another queued task resumes on the same container
    Then first-start repo update does not rerun unnecessarily
    And normal start behavior continues
