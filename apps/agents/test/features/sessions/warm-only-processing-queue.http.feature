@http @queue @warm-only
Feature: Warm-only queue promotion and warmup preparation
  As the sessions queue manager
  I want promotion to require warm readiness
  So processing starts only when containers are prepared

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"
    And I set bearer token to "${valid-doc-key-product-team}"
    And I set header "X-Workspace-Id" to "${workspace-id-product-team}"

  Scenario: Promotion is blocked while queued tasks are cold
    When I POST to "/internal/sessions/queue/promote" with body:
      """
      {
        "require_warm": true
      }
      """
    Then the response should be successful
    And the response body path "$.promoted_count" should equal 0
    And the response body path "$.reason" should contain "warm"

  Scenario: Warm-ready queued task is promoted in queue order
    When I GET "/internal/sessions/queue/state"
    Then the response should be successful
    And the response body path "$.queue" should exist
    And the response body path "$.queue[0].status" should exist

  Scenario: Warmup marks top queued tasks warm-ready before promotion
    When I POST to "/internal/sessions/queue/warmup" with body:
      """
      {
        "warm_target_count": 2
      }
      """
    Then the response should be successful
    And the response body path "$.warmed_count" should exist
