@security
Feature: ERM API Security Headers
  As a security engineer
  I want to verify the Entity Relationship Manager API returns proper security headers
  So that API responses are hardened against MIME-sniffing, clickjacking, and other client-side attacks

  Background:
    # baseUrl is auto-injected from exo-bdd config (http.baseURL → http://localhost:4006)
    Given I set variable "healthEndpoint" to "${baseUrl}/health"
    Given I set variable "schemaEndpoint" to "${baseUrl}/api/v1/workspaces/product-team/schema"
    Given I set variable "entitiesEndpoint" to "${baseUrl}/api/v1/workspaces/product-team/entities"
    Given I set variable "edgesEndpoint" to "${baseUrl}/api/v1/workspaces/product-team/edges"
    Given I set variable "traverseEndpoint" to "${baseUrl}/api/v1/workspaces/product-team/traverse"

  # ---------------------------------------------------------------------------
  # Security Headers — Health Endpoint (unauthenticated)
  # Maps to: GET /health — the only unauthenticated endpoint; security headers
  # must be present even on unauthenticated responses to prevent MIME-sniffing,
  # clickjacking, and other client-side attacks on health check consumers.
  # ---------------------------------------------------------------------------

  Scenario: Health endpoint returns proper security headers
    When I check "${healthEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Referrer-Policy"
    And Content-Security-Policy should be present
    And Strict-Transport-Security should be present

  # ---------------------------------------------------------------------------
  # Security Headers — Schema Management Endpoint (authenticated)
  # Maps to: GET /api/v1/workspaces/:workspace_id/schema
  # PUT /api/v1/workspaces/:workspace_id/schema
  # The SecurityHeadersPlug is applied at the pipeline level, so testing the
  # GET route covers all HTTP methods on the schema endpoint uniformly.
  # ---------------------------------------------------------------------------

  Scenario: Schema endpoint returns proper security headers
    When I check "${schemaEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Referrer-Policy"
    And Content-Security-Policy should be present
    And Strict-Transport-Security should be present

  # ---------------------------------------------------------------------------
  # Security Headers — Entity CRUD Endpoint (authenticated)
  # Maps to: POST/GET/PUT/DELETE /api/v1/workspaces/:workspace_id/entities
  # Entity endpoints accept user-controlled JSON body fields (type, properties)
  # and UUID parameters in the URL path. Security headers prevent client-side
  # attacks if entity data containing malicious content is reflected back.
  # ---------------------------------------------------------------------------

  Scenario: Entities endpoint returns proper security headers
    When I check "${entitiesEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Referrer-Policy"
    And Content-Security-Policy should be present
    And Strict-Transport-Security should be present

  # ---------------------------------------------------------------------------
  # Security Headers — Edge/Relationship Endpoint (authenticated)
  # Maps to: POST/GET/PUT/DELETE /api/v1/workspaces/:workspace_id/edges
  # Edge endpoints accept type names, source/target UUIDs, and property values
  # in JSON body — all potential vectors for stored content reflected in responses.
  # ---------------------------------------------------------------------------

  Scenario: Edges endpoint returns proper security headers
    When I check "${edgesEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Referrer-Policy"
    And Content-Security-Policy should be present
    And Strict-Transport-Security should be present

  # ---------------------------------------------------------------------------
  # Security Headers — Traversal Endpoint (authenticated)
  # Maps to: GET /api/v1/workspaces/:workspace_id/traverse
  # GET /api/v1/workspaces/:workspace_id/entities/:id/neighbors
  # GET /api/v1/workspaces/:workspace_id/entities/:id/paths/:target_id
  # Traversal endpoints return aggregated graph data from multiple entities
  # and edges — security headers prevent misinterpretation of complex responses.
  # ---------------------------------------------------------------------------

  Scenario: Traverse endpoint returns proper security headers
    When I check "${traverseEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Referrer-Policy"
    And Content-Security-Policy should be present
    And Strict-Transport-Security should be present

  # ---------------------------------------------------------------------------
  # Security Headers — Specific Header Value Assertions
  # Maps to: All endpoints — verify headers are not just present but configured
  # with secure values that match OWASP recommendations for JSON APIs.
  # ---------------------------------------------------------------------------

  Scenario: X-Frame-Options is set to DENY on health endpoint
    When I check "${healthEndpoint}" for security headers
    Then X-Frame-Options should be set to "DENY"

  Scenario: X-Frame-Options is set to DENY on entities endpoint
    When I check "${entitiesEndpoint}" for security headers
    Then X-Frame-Options should be set to "DENY"

  # ---------------------------------------------------------------------------
  # Security Headers — Additional Recommended Headers
  # Maps to: OWASP Secure Headers Project recommendations
  # Permissions-Policy restricts browser features (camera, geolocation, etc.)
  # that a JSON API should never need access to.
  # ---------------------------------------------------------------------------

  Scenario: Health endpoint includes Permissions-Policy header
    When I check "${healthEndpoint}" for security headers
    Then the security headers should include "Permissions-Policy"

  Scenario: Entities endpoint includes Permissions-Policy header
    When I check "${entitiesEndpoint}" for security headers
    Then the security headers should include "Permissions-Policy"

  # ---------------------------------------------------------------------------
  # NOTE: SSL/TLS certificate validation is skipped in the local test environment
  # because the test server runs over plain HTTP (http://localhost:4006).
  # In staging/production, SSL certificate checks should be added:
  #
  #   Scenario: SSL certificate is properly configured
  #     When I check SSL certificate for "https://erm.example.com"
  #     Then the SSL certificate should be valid
  #     And the SSL certificate should not expire within 30 days
  # ---------------------------------------------------------------------------
