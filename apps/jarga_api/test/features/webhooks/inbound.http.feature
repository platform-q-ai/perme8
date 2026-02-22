@http
Feature: Inbound Webhook API
  As an API consumer
  I want to receive and process inbound webhooks from external services via the REST API
  So that the platform can ingest data from third-party integrations securely

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # ---------------------------------------------------------------------------
  # Inbound Webhook - Successful payload delivery
  # ---------------------------------------------------------------------------

  Scenario: External service sends a valid webhook payload
    # Assumes: workspace product-team has an inbound webhook endpoint configured
    # Assumes: "${valid-inbound-signature}" is a valid HMAC signature for the payload below
    Given I set header "X-Webhook-Signature" to "${valid-inbound-signature}"
    When I POST to "/api/workspaces/product-team/webhooks/inbound" with body:
      """
      {
        "event": "external.resource_updated",
        "data": {
          "resource_id": "ext-123",
          "updated_at": "2026-02-22T10:00:00Z"
        }
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON

  Scenario: Accepted inbound webhook payload is routed to the appropriate handler
    # Assumes: "${valid-inbound-signature-routed}" is a valid HMAC signature for the payload below
    Given I set header "X-Webhook-Signature" to "${valid-inbound-signature-routed}"
    When I POST to "/api/workspaces/product-team/webhooks/inbound" with body:
      """
      {
        "event": "external.order_placed",
        "data": {
          "order_id": "ord-456",
          "amount": 99.99
        }
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON

  # ---------------------------------------------------------------------------
  # Inbound Webhook - Signature verification
  # ---------------------------------------------------------------------------

  Scenario: Inbound webhook with invalid signature is rejected
    # Assumes: workspace product-team has an inbound webhook endpoint configured
    Given I set header "X-Webhook-Signature" to "sha256=invalid-signature-value"
    When I POST to "/api/workspaces/product-team/webhooks/inbound" with body:
      """
      {
        "event": "external.resource_updated",
        "data": {
          "resource_id": "ext-789"
        }
      }
      """
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should exist

  Scenario: Inbound webhook with missing signature header is rejected
    # Assumes: workspace product-team has an inbound webhook endpoint configured
    # Note: No X-Webhook-Signature header is set
    When I POST to "/api/workspaces/product-team/webhooks/inbound" with body:
      """
      {
        "event": "external.resource_updated",
        "data": {
          "resource_id": "ext-321"
        }
      }
      """
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should exist

  # ---------------------------------------------------------------------------
  # Inbound Webhook - Audit logging
  # ---------------------------------------------------------------------------

  Scenario: Inbound webhook payload is recorded in the audit log
    # Assumes: "${valid-inbound-signature-audit}" is a valid HMAC signature for the payload below
    # Step 1: Send an inbound webhook
    Given I set header "X-Webhook-Signature" to "${valid-inbound-signature-audit}"
    When I POST to "/api/workspaces/product-team/webhooks/inbound" with body:
      """
      {
        "event": "external.audit_test",
        "data": {
          "trace_id": "audit-trace-001"
        }
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    # Step 2: Verify the audit log records the inbound webhook
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"
    And I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/inbound/logs"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data[0].event_type" should exist
    And the response body path "$.data[0].payload" should exist
    And the response body path "$.data[0].signature_valid" should be true
    And the response body path "$.data[0].received_at" should exist

  # ---------------------------------------------------------------------------
  # Inbound Webhook - Malformed payload
  # ---------------------------------------------------------------------------

  Scenario: Inbound webhook with malformed JSON is rejected
    # Assumes: "${valid-inbound-signature-malformed}" is a valid HMAC signature for the raw body
    Given I set header "X-Webhook-Signature" to "${valid-inbound-signature-malformed}"
    When I POST raw to "/api/workspaces/product-team/webhooks/inbound" with body:
      """
      {this is not valid json
      """
    Then the response status should be 400
    And the response body should be valid JSON
    And the response body path "$.error" should exist
