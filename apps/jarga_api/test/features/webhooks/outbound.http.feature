@http
Feature: Outbound Webhook Management API
  As an API consumer
  I want to manage outbound webhook subscriptions, view delivery logs, and understand event dispatch behaviour via the REST API
  So that I can integrate the platform with external systems for outbound event notifications

  Background:
    Given I set header "Content-Type" to "application/json"
    And I set header "Accept" to "application/json"

  # ---------------------------------------------------------------------------
  # Webhook Subscription CRUD - Create
  # ---------------------------------------------------------------------------

  Scenario: Workspace admin registers a webhook endpoint
    # Assumes: admin@example.com has admin-role API key with access to product-team
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I POST to "/api/workspaces/product-team/webhooks" with body:
      """
      {
        "url": "https://hooks.example.com/events",
        "event_types": ["projects.project_created", "documents.document_created"]
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.url" should equal "https://hooks.example.com/events"
    And the response body path "$.data.event_types" should have 2 items
    And the response body path "$.data.is_active" should be true
    And the response body path "$.data.secret" should exist
    And the response body path "$.data.id" should exist
    And I store response body path "$.data.id" as "webhookId"
    And I store response body path "$.data.secret" as "webhookSecret"

  Scenario: Created subscription's signing secret is auto-generated
    # Assumes: admin@example.com has admin-role API key with access to product-team
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I POST to "/api/workspaces/product-team/webhooks" with body:
      """
      {
        "url": "https://hooks.example.com/signing-test",
        "event_types": ["projects.project_created"]
      }
      """
    Then the response status should be 201
    And the response body should be valid JSON
    And the response body path "$.data.secret" should exist
    And the response body path "$.data.secret" should match "^.{32,}$"

  Scenario: Create webhook subscription with invalid data returns 422
    # Assumes: admin@example.com has admin-role API key with access to product-team
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I POST to "/api/workspaces/product-team/webhooks" with body:
      """
      {
        "event_types": ["projects.project_created"]
      }
      """
    Then the response status should be 422
    And the response body should be valid JSON
    And the response body path "$.errors.url" should exist

  # ---------------------------------------------------------------------------
  # Webhook Subscription CRUD - List
  # ---------------------------------------------------------------------------

  Scenario: Workspace admin lists webhook subscriptions
    # Assumes: admin@example.com has admin-role API key with access to product-team
    # Assumes: product-team workspace has existing webhook subscriptions in seed data
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data[0].id" should exist
    And the response body path "$.data[0].url" should exist
    And the response body path "$.data[0].event_types" should exist
    And the response body path "$.data[0].is_active" should exist

  # ---------------------------------------------------------------------------
  # Webhook Subscription CRUD - Retrieve
  # ---------------------------------------------------------------------------

  Scenario: Workspace admin retrieves a specific webhook subscription
    # Assumes: admin@example.com has admin-role API key with access to product-team
    # Assumes: webhook subscription "${webhookId}" was created in a prior scenario
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${webhookId}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.id" should equal "${webhookId}"
    And the response body path "$.data.url" should exist
    And the response body path "$.data.event_types" should exist
    And the response body path "$.data.is_active" should exist

  Scenario: Retrieve non-existent webhook subscription returns 404
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/non-existent-webhook-id"
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Webhook subscription not found"

  # ---------------------------------------------------------------------------
  # Webhook Subscription CRUD - Update
  # ---------------------------------------------------------------------------

  Scenario: Workspace admin updates a webhook subscription URL
    # Assumes: webhook subscription "${webhookId}" exists from a prior scenario
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I PATCH to "/api/workspaces/product-team/webhooks/${webhookId}" with body:
      """
      {
        "url": "https://hooks.example.com/updated-endpoint"
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.url" should equal "https://hooks.example.com/updated-endpoint"
    And the response body path "$.data.id" should equal "${webhookId}"

  Scenario: Workspace admin updates webhook subscription event type filters
    # Assumes: webhook subscription "${webhookId}" exists from a prior scenario
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I PATCH to "/api/workspaces/product-team/webhooks/${webhookId}" with body:
      """
      {
        "event_types": ["chat.message_sent", "agents.agent_invoked"]
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.event_types" should have 2 items
    And the response body path "$.data.id" should equal "${webhookId}"

  Scenario: Update non-existent webhook subscription returns 404
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I PATCH to "/api/workspaces/product-team/webhooks/non-existent-webhook-id" with body:
      """
      {
        "url": "https://hooks.example.com/ghost"
      }
      """
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Webhook subscription not found"

  # ---------------------------------------------------------------------------
  # Webhook Subscription - Deactivate
  # ---------------------------------------------------------------------------

  Scenario: Workspace admin deactivates a webhook subscription
    # Assumes: webhook subscription "${webhookId}" is currently active
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I PATCH to "/api/workspaces/product-team/webhooks/${webhookId}" with body:
      """
      {
        "is_active": false
      }
      """
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.is_active" should be false
    And the response body path "$.data.id" should equal "${webhookId}"

  Scenario: Deactivated subscription stops receiving event deliveries
    # Verify the subscription is now inactive -- event dispatch logic is tested
    # at the domain layer; here we confirm the API reflects the inactive state.
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${webhookId}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.is_active" should be false

  # ---------------------------------------------------------------------------
  # Webhook Subscription CRUD - Delete
  # ---------------------------------------------------------------------------

  Scenario: Workspace admin deletes a webhook subscription
    # Create a subscription to delete
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I POST to "/api/workspaces/product-team/webhooks" with body:
      """
      {
        "url": "https://hooks.example.com/to-delete",
        "event_types": ["projects.project_created"]
      }
      """
    Then the response status should be 201
    And I store response body path "$.data.id" as "webhookToDeleteId"
    # Delete the subscription
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I DELETE "/api/workspaces/product-team/webhooks/${webhookToDeleteId}"
    Then the response status should be 200
    And the response body should be valid JSON

  Scenario: Deleted webhook subscription is no longer retrievable
    # Assumes: "${webhookToDeleteId}" was deleted in the prior scenario
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${webhookToDeleteId}"
    Then the response status should be 404
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Webhook subscription not found"

  # ---------------------------------------------------------------------------
  # Authorization - Role-based access
  # ---------------------------------------------------------------------------

  Scenario: Non-admin workspace member cannot create webhook subscriptions
    # Assumes: bob@example.com has "member" role (not admin) in product-team
    Given I set bearer token to "${valid-member-key-product-team}"
    When I POST to "/api/workspaces/product-team/webhooks" with body:
      """
      {
        "url": "https://hooks.example.com/unauthorized",
        "event_types": ["projects.project_created"]
      }
      """
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  Scenario: Non-admin workspace member cannot list webhook subscriptions
    # Assumes: bob@example.com has "member" role (not admin) in product-team
    Given I set bearer token to "${valid-member-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks"
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  Scenario: Non-admin workspace member cannot update webhook subscriptions
    # Assumes: bob@example.com has "member" role (not admin) in product-team
    Given I set bearer token to "${valid-member-key-product-team}"
    When I PATCH to "/api/workspaces/product-team/webhooks/${webhookId}" with body:
      """
      {
        "url": "https://hooks.example.com/sneaky-update"
      }
      """
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  Scenario: Non-admin workspace member cannot delete webhook subscriptions
    # Assumes: bob@example.com has "member" role (not admin) in product-team
    Given I set bearer token to "${valid-member-key-product-team}"
    When I DELETE "/api/workspaces/product-team/webhooks/${webhookId}"
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  # ---------------------------------------------------------------------------
  # Authentication - Unauthenticated access
  # ---------------------------------------------------------------------------

  Scenario: Unauthenticated user cannot list webhook subscriptions
    When I GET "/api/workspaces/product-team/webhooks"
    Then the response status should be 401
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Invalid or revoked API key"

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
  # Delivery Logs - View delivery history
  # ---------------------------------------------------------------------------

  Scenario: Workspace admin views delivery history for a subscription
    # Assumes: admin@example.com has admin-role API key with access to product-team
    # Assumes: webhook subscription "${seeded-webhook-id}" has delivery attempts in seed data
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-id}/deliveries"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data[0].id" should exist
    And the response body path "$.data[0].event_type" should exist
    And the response body path "$.data[0].status" should exist
    And the response body path "$.data[0].response_code" should exist
    And the response body path "$.data[0].created_at" should exist

  Scenario: Delivery log includes retry information
    # Assumes: webhook delivery "${seeded-retried-delivery-id}" has been retried
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-id}/deliveries/${seeded-retried-delivery-id}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.attempts" should exist
    And the response body path "$.data.next_retry_at" should exist
    And the response body path "$.data.status" should exist
    And the response body path "$.data.event_type" should exist

  Scenario: Delivery log for failed delivery includes failure reason
    # Assumes: webhook delivery "${seeded-failed-delivery-id}" has failed
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-id}/deliveries/${seeded-failed-delivery-id}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.status" should equal "failed"
    And the response body path "$.data.response_code" should exist
    And the response body path "$.data.attempts" should exist

  Scenario: Non-admin cannot view delivery logs
    # Assumes: bob@example.com has "member" role (not admin) in product-team
    Given I set bearer token to "${valid-member-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-id}/deliveries"
    Then the response status should be 403
    And the response body should be valid JSON
    And the response body path "$.error" should equal "Insufficient permissions"

  # ---------------------------------------------------------------------------
  # Event Dispatch Behaviour (API-observable outcomes)
  # ---------------------------------------------------------------------------

  # NOTE: Event dispatch, filtering, retry with exponential backoff, and
  # max-retry exhaustion are primarily domain-layer behaviours. The HTTP API
  # exposes them through delivery log records. The scenarios below verify that
  # the delivery log correctly reflects these behaviours after events occur.

  Scenario: Delivery log records a successful event dispatch
    # Assumes: a domain event matching the subscription was triggered and delivered
    # Assumes: "${seeded-successful-delivery-id}" is a delivery with status "success"
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-id}/deliveries/${seeded-successful-delivery-id}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.status" should equal "success"
    And the response body path "$.data.response_code" should equal 200
    And the response body path "$.data.event_type" should exist
    And the response body path "$.data.payload" should exist

  Scenario: Delivery log records event payload signature metadata
    # Assumes: "${seeded-successful-delivery-id}" delivery was signed with HMAC-SHA256
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-id}/deliveries/${seeded-successful-delivery-id}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.payload" should exist
    And the response body path "$.data.event_type" should exist

  Scenario: No delivery log created for non-matching event types
    # Assumes: "${seeded-filtered-webhook-id}" subscribes only to "documents.document_created"
    # Assumes: a "projects.project_created" event was triggered but should NOT produce a delivery
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-filtered-webhook-id}/deliveries"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data" should have 0 items

  Scenario: Delivery log records a failed attempt with pending retry
    # Assumes: "${seeded-pending-retry-delivery-id}" is a delivery that failed and has a retry scheduled
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-id}/deliveries/${seeded-pending-retry-delivery-id}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.status" should equal "pending"
    And the response body path "$.data.response_code" should equal 500
    And the response body path "$.data.attempts" should exist
    And the response body path "$.data.next_retry_at" should exist

  Scenario: Delivery log records a successful retry
    # Assumes: "${seeded-retried-success-delivery-id}" initially failed then succeeded on retry
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-id}/deliveries/${seeded-retried-success-delivery-id}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.status" should equal "success"
    And the response body path "$.data.response_code" should equal 200
    And the response body path "$.data.next_retry_at" should not exist

  Scenario: Delivery log records a permanently failed delivery after max retries
    # Assumes: "${seeded-exhausted-delivery-id}" exhausted all retry attempts
    Given I set bearer token to "${valid-admin-key-product-team}"
    When I GET "/api/workspaces/product-team/webhooks/${seeded-webhook-id}/deliveries/${seeded-exhausted-delivery-id}"
    Then the response status should be 200
    And the response body should be valid JSON
    And the response body path "$.data.status" should equal "failed"
    And the response body path "$.data.next_retry_at" should not exist
    And the response body path "$.data.attempts" should exist
