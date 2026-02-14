@http
Feature: Health Check API
  As a platform operator
  I want to verify the ERM service health via its health endpoint
  So that I can monitor Neo4j connectivity and overall service availability

  # ---------------------------------------------------------------------------
  # GET /health — Health check (unauthenticated)
  # ---------------------------------------------------------------------------

  Scenario: Health endpoint is accessible without authentication
    When I GET "/health"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.status" should exist

  Scenario: Health endpoint returns Neo4j connection status
    When I GET "/health"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.status" should equal "ok"
    And the response body path "$.neo4j" should equal "connected"

  Scenario: Health endpoint responds within performance budget
    When I GET "/health"
    Then the response should be successful
    And the response time should be less than 200 ms

  Scenario: Health endpoint returns JSON content type
    When I GET "/health"
    Then the response status should be 200
    And the response should have content-type "application/json"
