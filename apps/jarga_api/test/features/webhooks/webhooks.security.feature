@security
Feature: Webhook API Security Baseline
  As a security engineer
  I want to verify the Webhook API endpoints are free from common vulnerabilities
  So that webhook subscriptions, delivery logs, inbound payloads, and signing secrets are protected against attack

  Background:
    # baseUrl is auto-injected from exo-bdd config (http.baseURL)
    # Outbound webhook subscription management endpoints
    Given I set variable "subscriptionListEndpoint" to "${baseUrl}/api/workspaces/product-team/webhooks/subscriptions"
    Given I set variable "subscriptionShowEndpoint" to "${baseUrl}/api/workspaces/product-team/webhooks/subscriptions/order-events"
    Given I set variable "deliveryLogsEndpoint" to "${baseUrl}/api/workspaces/product-team/webhooks/subscriptions/order-events/deliveries"
    # Inbound webhook receiver endpoint
    Given I set variable "inboundWebhookEndpoint" to "${baseUrl}/api/workspaces/product-team/webhooks/inbound/stripe"
    # Cross-workspace isolation endpoint
    Given I set variable "crossWorkspaceEndpoint" to "${baseUrl}/api/workspaces/engineering/webhooks/subscriptions"

  # ===========================================================================
  # Attack Surface Discovery
  # Maps to: All scenarios -- understanding the full webhook API surface before
  #          scanning. Webhook endpoints include subscription CRUD, delivery logs,
  #          and inbound receiver paths.
  # ===========================================================================

  Scenario: Spider discovers webhook subscription management attack surface
    Given a new ZAP session
    When I spider "${subscriptionListEndpoint}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers webhook subscription detail attack surface
    Given a new ZAP session
    When I spider "${subscriptionShowEndpoint}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers webhook delivery logs attack surface
    Given a new ZAP session
    When I spider "${deliveryLogsEndpoint}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers inbound webhook receiver attack surface
    Given a new ZAP session
    When I spider "${inboundWebhookEndpoint}"
    Then the spider should find at least 1 URLs

  # ===========================================================================
  # Passive Vulnerability Scanning -- Subscription Management Endpoints
  # Maps to: "Only workspace admins can manage webhook subscriptions",
  #          "Webhook subscription management requires authentication",
  #          "API key cannot access webhooks in a different workspace",
  #          "Webhook subscription URL must be HTTPS in production",
  #          "Webhook subscription URL is validated for format",
  #          "Webhook event type filters are validated"
  # ---------------------------------------------------------------------------
  # ZAP passive scanning detects information leakage, insecure headers, cookie
  # issues, and other non-intrusive findings on the subscription CRUD endpoints.
  # The business-logic authorization checks (admin-only, 401/403 responses) are
  # tested in the HTTP adapter feature; here we verify ZAP finds no passive
  # vulnerabilities in those same response flows.
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
  # Passive Vulnerability Scanning -- Delivery Logs Endpoint
  # Maps to: "Webhook delivery logs do not expose sensitive payload data"
  # ---------------------------------------------------------------------------
  # Passive scan checks that delivery log responses do not leak sensitive data
  # through verbose error messages, stack traces, or unredacted response bodies.
  # ===========================================================================

  Scenario: Passive scan on delivery logs endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${deliveryLogsEndpoint}"
    And I run a passive scan on "${deliveryLogsEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ===========================================================================
  # Passive Vulnerability Scanning -- Inbound Webhook Endpoint
  # Maps to: "Inbound webhooks reject tampered signatures",
  #          "Inbound webhooks reject missing signatures",
  #          "Inbound webhook payloads must be valid JSON",
  #          "Inbound webhook endpoints are rate limited"
  # ---------------------------------------------------------------------------
  # The inbound endpoint receives external HTTP POSTs with HMAC signatures.
  # Passive scanning verifies no information leakage in error responses (401,
  # 400, 429) that could aid an attacker in crafting valid signatures.
  # ===========================================================================

  Scenario: Passive scan on inbound webhook endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${inboundWebhookEndpoint}"
    And I run a passive scan on "${inboundWebhookEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ===========================================================================
  # Active Vulnerability Scanning -- SQL Injection
  # Maps to: All endpoints that accept user input:
  #          - URL slug parameters (:workspace_slug, :subscription_slug, :provider)
  #          - JSON body fields (url, event_types, description, payload)
  # Covers: Subscription CRUD, delivery log retrieval, inbound payload processing
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

  Scenario: No SQL Injection on delivery logs endpoint
    Given a new ZAP session
    When I spider "${deliveryLogsEndpoint}"
    And I run an active scan on "${deliveryLogsEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  Scenario: No SQL Injection on inbound webhook endpoint
    Given a new ZAP session
    When I spider "${inboundWebhookEndpoint}"
    And I run an active scan on "${inboundWebhookEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  # ===========================================================================
  # Active Vulnerability Scanning -- Cross-Site Scripting (XSS)
  # Maps to: Subscription CRUD where URL, description, and event type names are
  #          stored and later retrieved via GET -- potential for stored XSS.
  #          Delivery logs may echo back response bodies from external services.
  #          Inbound webhook payloads contain arbitrary JSON from third parties.
  # Covers: POST/PATCH body fields, GET response rendering, inbound payloads
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

  Scenario: No Cross-Site Scripting on delivery logs endpoint
    Given a new ZAP session
    When I spider "${deliveryLogsEndpoint}"
    And I run an active scan on "${deliveryLogsEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: No Cross-Site Scripting on inbound webhook endpoint
    Given a new ZAP session
    When I spider "${inboundWebhookEndpoint}"
    And I run an active scan on "${inboundWebhookEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  # ===========================================================================
  # Active Vulnerability Scanning -- Path Traversal
  # Maps to: Slug parameters in URL paths (:workspace_slug, :subscription_slug,
  #          :provider) -- attackers may attempt ../../etc/passwd style traversal
  # Covers: Subscription show/update/delete, delivery logs, inbound receiver
  # ===========================================================================

  Scenario: No path traversal on subscription detail endpoint
    Given a new ZAP session
    When I spider "${subscriptionShowEndpoint}"
    And I run an active scan on "${subscriptionShowEndpoint}"
    Then there should be no alerts of type "Path Traversal"

  Scenario: No path traversal on delivery logs endpoint
    Given a new ZAP session
    When I spider "${deliveryLogsEndpoint}"
    And I run an active scan on "${deliveryLogsEndpoint}"
    Then there should be no alerts of type "Path Traversal"

  Scenario: No path traversal on inbound webhook endpoint
    Given a new ZAP session
    When I spider "${inboundWebhookEndpoint}"
    And I run an active scan on "${inboundWebhookEndpoint}"
    Then there should be no alerts of type "Path Traversal"

  # ===========================================================================
  # Active Vulnerability Scanning -- Command Injection
  # Maps to: Subscription URL field (could be crafted as shell command if used
  #          in system calls), inbound webhook payload body (arbitrary JSON from
  #          external services), provider slug parameter
  # Covers: POST/PATCH body fields, inbound payload processing
  # ===========================================================================

  Scenario: No remote code execution on subscription list endpoint
    Given a new ZAP session
    When I spider "${subscriptionListEndpoint}"
    And I run an active scan on "${subscriptionListEndpoint}"
    Then there should be no alerts of type "Remote OS Command Injection"

  Scenario: No remote code execution on inbound webhook endpoint
    Given a new ZAP session
    When I spider "${inboundWebhookEndpoint}"
    And I run an active scan on "${inboundWebhookEndpoint}"
    Then there should be no alerts of type "Remote OS Command Injection"

  # ===========================================================================
  # Active Vulnerability Scanning -- Server-Side Request Forgery (SSRF)
  # Maps to: "Webhook subscription URL must be HTTPS in production",
  #          "Webhook subscription URL is validated for format"
  # ---------------------------------------------------------------------------
  # Subscription creation accepts a callback URL that the platform will later
  # POST to. If URL validation is insufficient, an attacker could register
  # internal/private network URLs (e.g., http://169.254.169.254/metadata,
  # http://localhost:6379) causing the server to make requests on their behalf.
  # ===========================================================================

  Scenario: No SSRF on subscription creation endpoint
    Given a new ZAP session
    When I spider "${subscriptionListEndpoint}"
    And I run an active scan on "${subscriptionListEndpoint}"
    Then there should be no alerts of type "Server Side Request Forgery"

  # ===========================================================================
  # Active Vulnerability Scanning -- Cross-Workspace Isolation
  # Maps to: "API key cannot access webhooks in a different workspace"
  # ---------------------------------------------------------------------------
  # Tests scanning the cross-workspace endpoint for authorization bypass vulns.
  # A scoped API key for workspace A should not be able to list, create, or
  # manage webhook subscriptions in workspace B.
  # ===========================================================================

  Scenario: No authorization bypass on cross-workspace webhook access
    Given a new ZAP session
    When I spider "${crossWorkspaceEndpoint}"
    And I run an active scan on "${crossWorkspaceEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Path Traversal"

  # ===========================================================================
  # Baseline Scans -- Quick Combined Spider + Passive
  # Maps to: Overall webhook API health check across all endpoint groups
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

  Scenario: Baseline scan on delivery logs endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${deliveryLogsEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on inbound webhook endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${inboundWebhookEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  # ===========================================================================
  # Comprehensive Active Scan -- Full Webhook API
  # Maps to: All scenarios combined -- deep active scan across all endpoints
  # ===========================================================================

  Scenario: Comprehensive active scan on webhook API finds no high-risk vulnerabilities
    Given a new ZAP session
    When I spider "${subscriptionListEndpoint}"
    And I spider "${subscriptionShowEndpoint}"
    And I spider "${deliveryLogsEndpoint}"
    And I spider "${inboundWebhookEndpoint}"
    And I run an active scan on "${subscriptionListEndpoint}"
    And I run an active scan on "${subscriptionShowEndpoint}"
    And I run an active scan on "${deliveryLogsEndpoint}"
    And I run an active scan on "${inboundWebhookEndpoint}"
    Then no high risk alerts should be found
    And I store the alerts as "comprehensiveScanAlerts"
    And I should see the alert details

  # ===========================================================================
  # Security Headers -- API Response Hardening
  # Maps to: "Webhook API endpoints return proper security headers"
  # ---------------------------------------------------------------------------
  # Every webhook API response should include security headers to prevent
  # MIME-sniffing, clickjacking, and other client-side attacks.
  # NOTE: checkSecurityHeaders sends a GET request, so we test against
  # endpoints with GET routes. The SecurityHeadersPlug is applied at the
  # pipeline level, covering all HTTP methods uniformly.
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

  Scenario: Delivery logs endpoint returns proper security headers
    When I check "${deliveryLogsEndpoint}" for security headers
    Then the security headers should include "X-Content-Type-Options"
    And the security headers should include "X-Frame-Options"
    And the security headers should include "Referrer-Policy"
    And Content-Security-Policy should be present
    And Strict-Transport-Security should be present

  # ===========================================================================
  # NOTE: SSL/TLS certificate validation is skipped in the local test
  # environment because the test server runs over plain HTTP. In
  # staging/production, SSL certificate checks should be added against
  # the HTTPS endpoint:
  #
  #   Scenario: SSL certificate is properly configured
  #     When I check SSL certificate for "https://api.example.com"
  #     Then the SSL certificate should be valid
  #     And the SSL certificate should not expire within 90 days
  # ===========================================================================

  # ===========================================================================
  # NOTE: The following generic feature scenarios test business-logic security
  # properties that are NOT testable via ZAP vulnerability scanning. These are
  # covered by the HTTP adapter feature (webhooks.http.feature) instead:
  #
  # - "Only workspace admins can manage webhook subscriptions"
  #   (Role-based access control -- requires authenticated API calls with
  #    different role tokens; ZAP scans test for injection/bypass, not RBAC)
  #
  # - "Webhook subscription management requires authentication"
  #   (401 response for unauthenticated requests -- tested via HTTP adapter
  #    with missing/invalid Authorization headers)
  #
  # - "API key cannot access webhooks in a different workspace"
  #   (Cross-workspace isolation at app layer -- ZAP scans the endpoint for
  #    injection vulns above; the authorization logic is tested via HTTP)
  #
  # - "Outbound webhook payloads are signed with HMAC-SHA256"
  #   (Cryptographic signing of outbound deliveries -- internal implementation
  #    detail; not observable from an external security scan)
  #
  # - "Inbound webhooks reject tampered signatures"
  # - "Inbound webhooks reject missing signatures"
  #   (HMAC signature verification -- requires crafting specific signature
  #    headers; tested via HTTP adapter with valid/invalid/missing signatures)
  #
  # - "Webhook subscription URL must be HTTPS in production"
  # - "Webhook subscription URL is validated for format"
  # - "Webhook event type filters are validated"
  #   (Input validation rules -- tested via HTTP adapter with specific invalid
  #    payloads; ZAP active scanning covers injection via these fields above)
  #
  # - "Inbound webhook payloads must be valid JSON"
  #   (Content-type / parsing validation -- tested via HTTP adapter)
  #
  # - "Inbound webhook endpoints are rate limited"
  #   (429 response under load -- requires rapid sequential requests;
  #    tested via HTTP adapter or load testing, not ZAP scanning)
  #
  # - "Webhook signing secrets are not exposed in API responses"
  #   (Data redaction in GET responses -- tested via HTTP adapter by
  #    asserting the signing_secret field is absent from JSON responses)
  #
  # - "Webhook delivery logs do not expose sensitive payload data"
  #   (Response body truncation/redaction -- tested via HTTP adapter by
  #    asserting delivery log entries have redacted response_body fields)
  # ===========================================================================

  # ===========================================================================
  # Security Reporting -- Audit Trail
  # Maps to: Compliance requirement -- generate artifacts after full scan suite
  # ===========================================================================

  Scenario: Generate security audit report for webhook API
    Given a new ZAP session
    When I spider "${subscriptionListEndpoint}"
    And I spider "${subscriptionShowEndpoint}"
    And I spider "${deliveryLogsEndpoint}"
    And I spider "${inboundWebhookEndpoint}"
    And I run a passive scan on "${subscriptionListEndpoint}"
    And I run a passive scan on "${subscriptionShowEndpoint}"
    And I run a passive scan on "${deliveryLogsEndpoint}"
    And I run a passive scan on "${inboundWebhookEndpoint}"
    And I run an active scan on "${subscriptionListEndpoint}"
    And I run an active scan on "${subscriptionShowEndpoint}"
    And I run an active scan on "${deliveryLogsEndpoint}"
    And I run an active scan on "${inboundWebhookEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"
    And there should be no alerts of type "Path Traversal"
    And there should be no alerts of type "Remote OS Command Injection"
    And there should be no alerts of type "Server Side Request Forgery"
    And I should see the alert details
    When I save the security report to "reports/webhook-api-security-audit.html"
    And I save the security report as JSON to "reports/webhook-api-security-audit.json"
