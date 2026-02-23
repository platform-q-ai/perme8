@http
Feature: Inbound Webhooks API
  As an external service
  I want to send webhook payloads to the platform's inbound endpoint
  So that I can push events and data into the platform for processing

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # ---------------------------------------------------------------------------
  # Inbound Webhook - Valid Payloads
  # ---------------------------------------------------------------------------

  Scenario: External service sends a valid webhook payload
    # Assumes: workspace product-team has an inbound webhook endpoint configured
    # Assumes: ${inbound-webhook-secret-product-team} is the known HMAC secret
    # Assumes: ${valid-inbound-signature} is a pre-computed HMAC-SHA256 signature for the payload
    Given I set header "X-Webhook-Signature" to "${valid-inbound-signature}"
    When I POST to "/api/workspaces/product-team/webhooks/inbound" with body:
      """
      {
        "event_type": "external.event.received",
        "payload": {
          "source": "partner-system",
          "data": {"key": "value"}
        }
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON

  Scenario: Accepted inbound webhook payload is routed to the appropriate handler
    # Assumes: pre-computed valid signature for the routable payload below
    Given I set header "X-Webhook-Signature" to "${valid-inbound-signature-routable}"
    When I POST to "/api/workspaces/product-team/webhooks/inbound" with body:
      """
      {
        "event_type": "document.sync",
        "payload": {
          "source": "external-cms",
          "document_id": "ext-doc-123",
          "action": "update"
        }
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON

  # ---------------------------------------------------------------------------
  # Inbound Webhook - Signature Verification Failures
  # ---------------------------------------------------------------------------

  Scenario: Inbound webhook with invalid signature is rejected
    # Assumes: workspace product-team has an inbound webhook endpoint configured
    Given I set header "X-Webhook-Signature" to "sha256=invalid-signature-value"
    When I POST to "/api/workspaces/product-team/webhooks/inbound" with body:
      """
      {
        "event_type": "external.event.received",
        "payload": {"data": "test"}
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
        "event_type": "external.event.received",
        "payload": {"data": "test"}
      }
      """
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should exist

  # ---------------------------------------------------------------------------
  # Inbound Webhook - Malformed Payloads
  # ---------------------------------------------------------------------------

  Scenario: Inbound webhook with malformed JSON is rejected
    # Assumes: valid signature is computed against the raw malformed body
    Given I set header "X-Webhook-Signature" to "${valid-inbound-signature-malformed}"
    When I POST raw to "/api/workspaces/product-team/webhooks/inbound" with body:
      """
      {this is not valid json
      """
    Then the response status should be 400
    And the response body should be valid JSON
    And the response body path "$.error" should exist

  # ---------------------------------------------------------------------------
  # Inbound Webhook - Audit Logging
  # ---------------------------------------------------------------------------

  Scenario: Inbound webhook payload is recorded in the audit log
    # First, send a valid inbound webhook so it gets recorded
    Given I set header "X-Webhook-Signature" to "${valid-inbound-signature-audit}"
    When I POST to "/api/workspaces/product-team/webhooks/inbound" with body:
      """
      {
        "event_type": "audit.test.event",
        "payload": {
          "source": "audit-test",
          "data": {"key": "audit-value"}
        }
      }
      """
    Then the response status should be 200
    # Now retrieve the inbound webhook audit logs as an admin
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"
    And I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/inbound/logs"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should exist
    And the response body path "$.data[0].event_type" should exist
    And the response body path "$.data[0].payload" should exist
    And the response body path "$.data[0].signature_valid" should exist
    And the response body path "$.data[0].received_at" should exist
