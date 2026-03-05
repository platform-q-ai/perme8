@security
Feature: Webhooks API Security Baseline
  As a security engineer
  I want to verify the Webhooks API endpoints are free from common vulnerabilities
  So that webhook secrets, HMAC signatures, delivery data, and workspace isolation are protected against attack

  Background:
    # baseUrl is auto-injected from exo-bdd config (http.baseURL)
    # Outbound webhook subscription management (Bearer token auth)
    Given I set variable "subscriptionListEndpoint" to "${baseUrl}/api/workspaces/product-team/webhooks"
    Given I set variable "subscriptionShowEndpoint" to "${baseUrl}/api/workspaces/product-team/webhooks/${seeded-webhook-id}"
    # Delivery log viewing (Bearer token auth)
    Given I set variable "deliveryLogEndpoint" to "${baseUrl}/api/workspaces/product-team/webhooks/${seeded-webhook-with-deliveries-id}/deliveries"
    # Inbound webhook receiver (HMAC signature auth, no Bearer token)
    Given I set variable "inboundWebhookEndpoint" to "${baseUrl}/api/workspaces/product-team/webhooks/inbound"
    # Inbound webhook audit logs (Bearer token auth)
    Given I set variable "inboundAuditLogEndpoint" to "${baseUrl}/api/workspaces/product-team/webhooks/inbound/logs"
    # Cross-workspace endpoint for isolation testing
    Given I set variable "crossWorkspaceEndpoint" to "${baseUrl}/api/workspaces/engineering/webhooks"

  # ===========================================================================
  # ATTACK SURFACE DISCOVERY
  # Maps to: all scenarios -- understanding the full webhook API surface
  # before scanning. Webhooks expose outbound subscription CRUD, delivery logs,
  # inbound webhook receiver, and inbound audit logs.
  # ===========================================================================

  Scenario: Spider discovers outbound webhook subscription list attack surface
    Given a new ZAP session
    When I spider "${subscriptionListEndpoint}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers outbound webhook subscription detail attack surface
    Given a new ZAP session
    When I spider "${subscriptionShowEndpoint}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers delivery log attack surface
    Given a new ZAP session
    When I spider "${deliveryLogEndpoint}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers inbound webhook receiver attack surface
    Given a new ZAP session
    When I spider "${inboundWebhookEndpoint}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers inbound webhook audit log attack surface
    Given a new ZAP session
    When I spider "${inboundAuditLogEndpoint}"
    Then the spider should find at least 1 URLs

  # ===========================================================================
  # PASSIVE VULNERABILITY SCANNING -- Outbound Webhook Subscription Endpoints
  # Maps to: Workspace admin registers/lists/retrieves/updates/deletes webhook
  #          subscriptions; Non-admin returns 403; Unauthenticated returns 401
  # Checks: Information leakage (signing secrets in responses), insecure
  #         headers, cookie issues, verbose error messages
  # ===========================================================================

  Scenario: Passive scan on subscription list endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${subscriptionListEndpoint}"
    And I run a passive scan on "${subscriptionListEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  Scenario: Passive scan on subscription detail endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${subscriptionShowEndpoint}"
    And I run a passive scan on "${subscriptionShowEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ===========================================================================
  # PASSIVE VULNERABILITY SCANNING -- Delivery Log Endpoint
  # Maps to: Workspace admin views delivery history; Non-admin returns 403
  # Checks: Delivery log responses should not leak full request/response bodies
  #         or signing secrets; proper status codes for unauthorized access
  # ===========================================================================

  Scenario: Passive scan on delivery log endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${deliveryLogEndpoint}"
    And I run a passive scan on "${deliveryLogEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ===========================================================================
  # PASSIVE VULNERABILITY SCANNING -- Inbound Webhook Receiver
  # Maps to: External service sends a valid webhook payload (200);
  #          Inbound webhook with invalid signature is rejected (401)
  # Checks: The inbound endpoint uses HMAC-SHA256 signature verification
  #         instead of Bearer tokens -- responses should not leak signing
  #         secrets or internal error details on signature validation failure
  # ===========================================================================

  Scenario: Passive scan on inbound webhook receiver finds no high-risk issues
    Given a new ZAP session
    When I spider "${inboundWebhookEndpoint}"
    And I run a passive scan on "${inboundWebhookEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ===========================================================================
  # PASSIVE VULNERABILITY SCANNING -- Inbound Webhook Audit Logs
  # Maps to: Inbound webhook audit logs are accessible to admins
  # Checks: Audit logs should not leak HMAC secrets or raw payloads
  # ===========================================================================

  Scenario: Passive scan on inbound audit log endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${inboundAuditLogEndpoint}"
    And I run a passive scan on "${inboundAuditLogEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- SQL Injection
  # Maps to: All endpoints that accept user input -- subscription ID in URL
  #          path, JSON body with URL/event_type fields on create/update,
  #          inbound webhook payload body, query parameters on delivery logs
  # Covers: Subscription CRUD, delivery log filtering, inbound payload parsing
  # ===========================================================================

  Scenario: No SQL Injection on subscription list endpoint
    Given a new ZAP session
    When I spider "${subscriptionListEndpoint}"
    And I run an active scan on "${subscriptionListEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  Scenario: No SQL Injection on subscription detail endpoint
    Given a new ZAP session
    When I spider "${subscriptionShowEndpoint}"
    And I run an active scan on "${subscriptionShowEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  Scenario: No SQL Injection on delivery log endpoint
    Given a new ZAP session
    When I spider "${deliveryLogEndpoint}"
    And I run an active scan on "${deliveryLogEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  Scenario: No SQL Injection on inbound webhook receiver
    Given a new ZAP session
    When I spider "${inboundWebhookEndpoint}"
    And I run an active scan on "${inboundWebhookEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- Cross-Site Scripting (XSS)
  # Maps to: Create/update subscription scenarios where URL and event_type
  #          fields are stored and later retrieved -- potential for stored XSS
  #          if content is rendered in a management UI. Inbound webhook payloads
  #          are stored and shown in audit logs -- another XSS vector.
  # Covers: Subscription URL field, event type filters, inbound payload body,
  #         delivery log response bodies
  # ===========================================================================

  Scenario: No Cross-Site Scripting on subscription list endpoint
    Given a new ZAP session
    When I spider "${subscriptionListEndpoint}"
    And I run an active scan on "${subscriptionListEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: No Cross-Site Scripting on subscription detail endpoint
    Given a new ZAP session
    When I spider "${subscriptionShowEndpoint}"
    And I run an active scan on "${subscriptionShowEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: No Cross-Site Scripting on inbound webhook receiver
    Given a new ZAP session
    When I spider "${inboundWebhookEndpoint}"
    And I run an active scan on "${inboundWebhookEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: No Cross-Site Scripting on inbound audit log endpoint
    Given a new ZAP session
    When I spider "${inboundAuditLogEndpoint}"
    And I run an active scan on "${inboundAuditLogEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- Path Traversal
  # Maps to: Subscription ID parameter in URL path, workspace slug parameter,
  #          delivery log subscription reference -- attackers may attempt
  #          ../../etc/passwd style traversal via subscription IDs or slugs
  # Covers: GET/PATCH/DELETE subscription by ID, delivery log by subscription
  # ===========================================================================

  Scenario: No path traversal on subscription detail endpoint
    Given a new ZAP session
    When I spider "${subscriptionShowEndpoint}"
    And I run an active scan on "${subscriptionShowEndpoint}"
    Then there should be no alerts of type "Path Traversal"

  Scenario: No path traversal on delivery log endpoint
    Given a new ZAP session
    When I spider "${deliveryLogEndpoint}"
    And I run an active scan on "${deliveryLogEndpoint}"
    Then there should be no alerts of type "Path Traversal"

  Scenario: No path traversal on inbound webhook receiver
    Given a new ZAP session
    When I spider "${inboundWebhookEndpoint}"
    And I run an active scan on "${inboundWebhookEndpoint}"
    Then there should be no alerts of type "Path Traversal"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- Command Injection
  # Maps to: Subscription URL field could be crafted as a shell command if
  #          the outbound delivery system shells out to curl/wget. Inbound
  #          webhook payloads could contain command injection if parsed
  #          unsafely. Event type filter strings are another vector.
  # Covers: Subscription create/update URL field, inbound payload body
  # ===========================================================================

  Scenario: No remote code execution on subscription list endpoint
    Given a new ZAP session
    When I spider "${subscriptionListEndpoint}"
    And I run an active scan on "${subscriptionListEndpoint}"
    Then there should be no alerts of type "Remote OS Command Injection"

  Scenario: No remote code execution on subscription detail endpoint
    Given a new ZAP session
    When I spider "${subscriptionShowEndpoint}"
    And I run an active scan on "${subscriptionShowEndpoint}"
    Then there should be no alerts of type "Remote OS Command Injection"

  Scenario: No remote code execution on inbound webhook receiver
    Given a new ZAP session
    When I spider "${inboundWebhookEndpoint}"
    And I run an active scan on "${inboundWebhookEndpoint}"
    Then there should be no alerts of type "Remote OS Command Injection"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- Server-Side Request Forgery (SSRF)
  # Maps to: Workspace admin registers a webhook endpoint -- the subscription
  #          URL field is a user-controlled URL that the server will later
  #          make HTTP requests to during outbound delivery. An attacker could
  #          supply an internal URL (e.g., http://169.254.169.254/metadata)
  #          to probe internal infrastructure.
  # Covers: Subscription create and update operations
  # ===========================================================================

  Scenario: No SSRF on subscription list endpoint
    Given a new ZAP session
    When I spider "${subscriptionListEndpoint}"
    And I run an active scan on "${subscriptionListEndpoint}"
    Then there should be no alerts of type "Server Side Request Forgery"

  Scenario: No SSRF on subscription detail endpoint
    Given a new ZAP session
    When I spider "${subscriptionShowEndpoint}"
    And I run an active scan on "${subscriptionShowEndpoint}"
    Then there should be no alerts of type "Server Side Request Forgery"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING -- Cross-Workspace Isolation
  # Maps to: "Non-admin workspace member cannot create webhook subscriptions"
  #          (403), "Unauthenticated user cannot access" (401)
  # Tests: Scanning the cross-workspace endpoint for authorization bypass
  #        vulnerabilities -- ensures workspace A admin cannot manage
  #        workspace B subscriptions via parameter manipulation
  # ===========================================================================

  Scenario: No authorization bypass on cross-workspace webhook access
    Given a new ZAP session
    When I spider "${crossWorkspaceEndpoint}"
    And I run an active scan on "${crossWorkspaceEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Path Traversal"

  # ===========================================================================
  # COMPREHENSIVE ACTIVE SCAN -- Full Webhooks API
  # Maps to: All scenarios combined -- deep active scan across all endpoints
  #          including outbound subscription CRUD, delivery logs, inbound
  #          webhook receiver, and inbound audit logs
  # ===========================================================================

  Scenario: Comprehensive active scan on webhooks API finds no high-risk vulnerabilities
    Given a new ZAP session
    When I spider "${subscriptionListEndpoint}"
    And I spider "${subscriptionShowEndpoint}"
    And I spider "${deliveryLogEndpoint}"
    And I spider "${inboundWebhookEndpoint}"
    And I spider "${inboundAuditLogEndpoint}"
    And I run an active scan on "${subscriptionListEndpoint}"
    And I run an active scan on "${subscriptionShowEndpoint}"
    And I run an active scan on "${deliveryLogEndpoint}"
    And I run an active scan on "${inboundWebhookEndpoint}"
    And I run an active scan on "${inboundAuditLogEndpoint}"
    Then no high risk alerts should be found
    And I store the alerts as "comprehensiveScanAlerts"
    And I should see the alert details

  # ===========================================================================
  # BASELINE SCAN -- Quick Combined Spider + Passive
  # Maps to: Overall webhooks API health check across all endpoint groups
  # ===========================================================================

  Scenario: Baseline scan on subscription list endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${subscriptionListEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on subscription detail endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${subscriptionShowEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on delivery log endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${deliveryLogEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on inbound webhook receiver passes
    Given a new ZAP session
    When I run a baseline scan on "${inboundWebhookEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on inbound audit log endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${inboundAuditLogEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  # ===========================================================================
  # SECURITY HEADERS -- API Response Hardening
  # Maps to: All API responses -- every webhook endpoint that returns JSON
  #          should include proper security headers to prevent MIME-sniffing,
  #          clickjacking, etc. This covers both Bearer-token-authenticated
  #          endpoints and the HMAC-authenticated inbound receiver.
  # NOTE: checkSecurityHeaders sends a GET request, so we test against
  #       endpoints with GET routes. The Perme8.Plugs.SecurityHeaders plug is applied at
  #       the pipeline level, covering all HTTP methods uniformly.
  # ===========================================================================

  Scenario: Subscription list endpoint returns proper security headers
    When I check "${subscriptionListEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Referrer-Policy"
    And Content-Security-Policy should be present
    And Strict-Transport-Security should be present

  Scenario: Subscription detail endpoint returns proper security headers
    When I check "${subscriptionShowEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Referrer-Policy"
    And Content-Security-Policy should be present
    And Strict-Transport-Security should be present

  Scenario: Delivery log endpoint returns proper security headers
    When I check "${deliveryLogEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Referrer-Policy"
    And Content-Security-Policy should be present
    And Strict-Transport-Security should be present

  Scenario: Inbound webhook receiver returns proper security headers
    When I check "${inboundWebhookEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Referrer-Policy"
    And Content-Security-Policy should be present
    And Strict-Transport-Security should be present

  Scenario: Inbound audit log endpoint returns proper security headers
    When I check "${inboundAuditLogEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Referrer-Policy"
    And Content-Security-Policy should be present
    And Strict-Transport-Security should be present

  # ===========================================================================
  # NOTE: SSL/TLS certificate validation is skipped in the local test
  # environment because the test server runs over plain HTTP. In
  # staging/production, SSL certificate checks should be added against the
  # HTTPS endpoint. This is especially important for webhooks because:
  # - Outbound webhook delivery URLs should enforce HTTPS in production
  # - Inbound webhook receivers must verify signatures over TLS to prevent
  #   man-in-the-middle attacks that could forge HMAC signatures
  # ===========================================================================

  # ===========================================================================
  # SECURITY REPORTING -- Audit Trail
  # Maps to: Compliance requirement -- generate artifacts after full scan
  #          suite covering all webhook endpoint groups
  # ===========================================================================

  Scenario: Generate security audit report for webhooks API
    Given a new ZAP session
    When I spider "${subscriptionListEndpoint}"
    And I spider "${subscriptionShowEndpoint}"
    And I spider "${deliveryLogEndpoint}"
    And I spider "${inboundWebhookEndpoint}"
    And I spider "${inboundAuditLogEndpoint}"
    And I run a passive scan on "${subscriptionListEndpoint}"
    And I run a passive scan on "${subscriptionShowEndpoint}"
    And I run a passive scan on "${deliveryLogEndpoint}"
    And I run a passive scan on "${inboundWebhookEndpoint}"
    And I run a passive scan on "${inboundAuditLogEndpoint}"
    And I run an active scan on "${subscriptionListEndpoint}"
    And I run an active scan on "${subscriptionShowEndpoint}"
    And I run an active scan on "${deliveryLogEndpoint}"
    And I run an active scan on "${inboundWebhookEndpoint}"
    And I run an active scan on "${inboundAuditLogEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"
    And there should be no alerts of type "Path Traversal"
    And there should be no alerts of type "Remote OS Command Injection"
    And there should be no alerts of type "Server Side Request Forgery"
    And I should see the alert details
    When I save the security report to "reports/webhooks-api-security-audit.html"
    And I save the security report as JSON to "reports/webhooks-api-security-audit.json"
