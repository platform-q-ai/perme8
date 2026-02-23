@http
Feature: Outbound Webhooks API
  As an API consumer
  I want to manage outbound webhook subscriptions and view delivery logs via the REST API
  So that I can integrate the platform with external systems for event notifications

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # ---------------------------------------------------------------------------
  # Webhook Subscription CREATE Endpoint
  # ---------------------------------------------------------------------------

  Scenario: Workspace admin registers a webhook endpoint
    # Assumes: admin user has API key with admin access to product-team workspace
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I POST to "/api/workspaces/product-team/webhooks" with body:
      """
      {
        "url": "https://example.com/hooks/events",
        "event_types": ["document.created", "project.updated"]
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.url" should equal "https://example.com/hooks/events"
    And the response body path "$.data.event_types" should have 2 items
    And the response body path "$.data.secret" should exist
    And the response body path "$.data.is_active" should be true
    And the response body path "$.data.id" should exist
    And I store response body path "$.data.id" as "createdWebhookId"
    And I store response body path "$.data.secret" as "createdWebhookSecret"

  Scenario: Created subscription has an auto-generated signing secret of sufficient length
    # Assumes: admin user has API key with admin access to product-team workspace
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I POST to "/api/workspaces/product-team/webhooks" with body:
      """
      {
        "url": "https://example.com/hooks/secret-test",
        "event_types": ["document.created"]
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.secret" should exist
    And the response body path "$.data.secret" should match "^.{32,}$"

  Scenario: Create webhook subscription with invalid data returns validation error
    # Assumes: admin user has API key with admin access to product-team workspace
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I POST to "/api/workspaces/product-team/webhooks" with body:
      """
      {
        "event_types": ["document.created"]
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors.url" should exist

  # ---------------------------------------------------------------------------
  # Webhook Subscription LIST Endpoint
  # ---------------------------------------------------------------------------

  Scenario: Workspace admin lists webhook subscriptions
    # Assumes: workspace product-team has seeded webhook subscriptions
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should exist
    And the response body path "$.data[0].id" should exist
    And the response body path "$.data[0].url" should exist
    And the response body path "$.data[0].event_types" should exist
    And the response body path "$.data[0].is_active" should exist
    And the response body path "$.data[0].secret" should not exist

  # ---------------------------------------------------------------------------
  # Webhook Subscription GET Endpoint
  # ---------------------------------------------------------------------------

  Scenario: Workspace admin retrieves a specific webhook subscription
    # Assumes: seeded webhook subscription exists in product-team workspace
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-id}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.id" should exist
    And the response body path "$.data.url" should exist
    And the response body path "$.data.event_types" should exist
    And the response body path "$.data.is_active" should exist
    And the response body path "$.data.secret" should not exist

  Scenario: Retrieve non-existent webhook subscription returns 404
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/00000000-0000-0000-0000-000000000000"
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Webhook subscription not found"

  # ---------------------------------------------------------------------------
  # Webhook Subscription UPDATE Endpoint
  # ---------------------------------------------------------------------------

  Scenario: Workspace admin updates a webhook subscription URL
    # Assumes: seeded webhook subscription exists in product-team workspace
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I PATCH to "/api/workspaces/product-team/webhooks/${seeded-webhook-id}" with body:
      """
      {
        "url": "https://example.com/hooks/updated-endpoint"
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.url" should equal "https://example.com/hooks/updated-endpoint"
    And the response body path "$.data.id" should exist

  Scenario: Workspace admin updates webhook event type filters
    # Assumes: seeded webhook subscription exists in product-team workspace
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I PATCH to "/api/workspaces/product-team/webhooks/${seeded-webhook-id}" with body:
      """
      {
        "event_types": ["project.created", "project.deleted", "document.updated"]
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.event_types" should have 3 items

  Scenario: Update non-existent webhook subscription returns 404
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I PATCH to "/api/workspaces/product-team/webhooks/00000000-0000-0000-0000-000000000000" with body:
      """
      {
        "url": "https://example.com/hooks/ghost"
      }
      """
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Webhook subscription not found"

  # ---------------------------------------------------------------------------
  # Webhook Subscription DEACTIVATE
  # ---------------------------------------------------------------------------

  Scenario: Workspace admin deactivates a webhook subscription
    # Assumes: seeded active webhook subscription exists in product-team workspace
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I PATCH to "/api/workspaces/product-team/webhooks/${seeded-active-webhook-id}" with body:
      """
      {
        "is_active": false
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.is_active" should be false

  Scenario: Deactivated subscription reflects inactive state on retrieval
    # Assumes: seeded webhook subscription has been deactivated
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-deactivated-webhook-id}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.is_active" should be false

  # ---------------------------------------------------------------------------
  # Webhook Subscription DELETE Endpoint
  # ---------------------------------------------------------------------------

  Scenario: Workspace admin deletes a webhook subscription
    # Create a subscription first, then delete it
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I POST to "/api/workspaces/product-team/webhooks" with body:
      """
      {
        "url": "https://example.com/hooks/to-delete",
        "event_types": ["document.created"]
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.id" as "webhookToDeleteId"
    # Now delete it
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I DELETE "/api/workspaces/product-team/webhooks/${webhookToDeleteId}"
    Then the response status should be between 200 and 204

  Scenario: Deleted webhook subscription is no longer retrievable
    # Assumes: a webhook subscription was previously deleted (via seed or prior scenario)
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-deleted-webhook-id}"
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should exist

  # ---------------------------------------------------------------------------
  # Authorization - Non-admin workspace members
  # ---------------------------------------------------------------------------

  Scenario: Non-admin workspace member cannot create webhook subscriptions
    # Assumes: member user has API key with member-level access to product-team
    Given I set bearer token to "${valid-member-key-product-team}"
    When I POST to "/api/workspaces/product-team/webhooks" with body:
      """
      {
        "url": "https://example.com/hooks/unauthorized",
        "event_types": ["document.created"]
      }
      """
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  Scenario: Non-admin workspace member cannot list webhook subscriptions
    # Assumes: member user has API key with member-level access to product-team
    Given I set bearer token to "${valid-member-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks"
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  Scenario: Non-admin cannot update webhook subscriptions
    # Assumes: member user has API key with member-level access to product-team
    Given I set bearer token to "${valid-member-key-product-team}"
    When I PATCH to "/api/workspaces/product-team/webhooks/${seeded-webhook-id}" with body:
      """
      {
        "url": "https://example.com/hooks/unauthorized-update"
      }
      """
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  Scenario: Non-admin cannot delete webhook subscriptions
    # Assumes: member user has API key with member-level access to product-team
    Given I set bearer token to "${valid-member-key-product-team}"
    When I DELETE "/api/workspaces/product-team/webhooks/${seeded-webhook-id}"
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  # ---------------------------------------------------------------------------
  # Authorization - Unauthenticated and invalid credentials
  # ---------------------------------------------------------------------------

  Scenario: Unauthenticated user cannot access webhook subscriptions
    When I GET "/api/workspaces/product-team/webhooks"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should exist

  Scenario: Invalid API key cannot access webhook subscriptions
    Given I set bearer token to "invalid-key-12345"
    When I GET "/api/workspaces/product-team/webhooks"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Invalid or revoked API key"

  Scenario: Revoked API key cannot access webhook subscriptions
    Given I set bearer token to "${revoked-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Invalid or revoked API key"

  # ---------------------------------------------------------------------------
  # Delivery Logs - LIST Endpoint
  # ---------------------------------------------------------------------------

  Scenario: Workspace admin views delivery history for a subscription
    # Assumes: seeded webhook subscription has delivery attempts in the system
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-with-deliveries-id}/deliveries"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should exist
    And the response body path "$.data[0].id" should exist
    And the response body path "$.data[0].event_type" should exist
    And the response body path "$.data[0].status" should exist
    And the response body path "$.data[0].response_code" should exist
    And the response body path "$.data[0].inserted_at" should exist

  Scenario: No delivery log for non-matching event types
    # Assumes: seeded webhook subscription filters for specific event types with no matching deliveries
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-no-deliveries-id}/deliveries"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should have 0 items

  # ---------------------------------------------------------------------------
  # Delivery Logs - GET Individual Delivery
  # ---------------------------------------------------------------------------

  Scenario: Delivery log includes retry information
    # Assumes: seeded delivery has been retried
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-with-deliveries-id}/deliveries/${seeded-retried-delivery-id}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.attempts" should exist
    And the response body path "$.data.next_retry_at" should exist
    And the response body path "$.data.status" should exist
    And the response body path "$.data.event_type" should exist

  Scenario: Delivery log for failed delivery includes failure reason
    # Assumes: seeded delivery has failed status
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-with-deliveries-id}/deliveries/${seeded-failed-delivery-id}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.status" should equal "failed"
    And the response body path "$.data.response_code" should exist
    And the response body path "$.data.attempts" should exist

  Scenario: Delivery log records a successful event dispatch
    # Assumes: seeded delivery was successfully dispatched
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-with-deliveries-id}/deliveries/${seeded-success-delivery-id}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.status" should equal "success"
    And the response body path "$.data.response_code" should equal 200
    And the response body path "$.data.event_type" should exist
    And the response body path "$.data.payload" should exist

  Scenario: Delivery log records event payload and event type
    # Assumes: seeded delivery was successfully dispatched with payload metadata
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-with-deliveries-id}/deliveries/${seeded-success-delivery-id}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.payload" should exist
    And the response body path "$.data.event_type" should exist

  Scenario: Delivery log records a failed attempt with pending retry
    # Assumes: seeded delivery failed and has a retry scheduled (status: pending)
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-with-deliveries-id}/deliveries/${seeded-pending-retry-delivery-id}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.status" should equal "pending"
    And the response body path "$.data.response_code" should equal 500
    And the response body path "$.data.attempts" should exist
    And the response body path "$.data.next_retry_at" should exist

  Scenario: Delivery log records a successful retry
    # Assumes: seeded delivery initially failed then succeeded on retry
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-with-deliveries-id}/deliveries/${seeded-retried-success-delivery-id}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.status" should equal "success"
    And the response body path "$.data.response_code" should equal 200
    And the response body path "$.data.next_retry_at" should not exist

  Scenario: Delivery log records a permanently failed delivery after max retries
    # Assumes: seeded delivery exhausted all retry attempts
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-with-deliveries-id}/deliveries/${seeded-exhausted-delivery-id}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.status" should equal "failed"
    And the response body path "$.data.next_retry_at" should not exist
    And the response body path "$.data.attempts" should exist

  # ---------------------------------------------------------------------------
  # Delivery Logs - Authorization
  # ---------------------------------------------------------------------------

  Scenario: Non-admin cannot view delivery logs
    # Assumes: member user has API key with member-level access to product-team
    Given I set bearer token to "${valid-member-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-with-deliveries-id}/deliveries"
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"
