@security
Feature: ERM API Security Baseline
  As a security engineer
  I want to verify the Entity Relationship Manager API endpoints are free from common vulnerabilities
  So that graph data, workspace isolation, and Neo4j/Cypher query parameters are protected against attack

  Background:
    # baseUrl is auto-injected from exo-bdd config (http.baseURL → http://localhost:4006)
    Given I set variable "healthEndpoint" to "${baseUrl}/health"
    Given I set variable "schemaEndpoint" to "${baseUrl}/api/v1/workspaces/product-team/schema"
    Given I set variable "entitiesEndpoint" to "${baseUrl}/api/v1/workspaces/product-team/entities"
    Given I set variable "edgesEndpoint" to "${baseUrl}/api/v1/workspaces/product-team/edges"
    Given I set variable "traverseEndpoint" to "${baseUrl}/api/v1/workspaces/product-team/traverse"

  # ===========================================================================
  # ATTACK SURFACE DISCOVERY
  # Maps to: All ERM endpoints — spider to map the full API surface before
  # running vulnerability scans. The ERM exposes schema, entity, edge,
  # traversal, and health endpoints.
  # ===========================================================================

  Scenario: Spider discovers health endpoint attack surface
    Given a new ZAP session
    When I spider "${healthEndpoint}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers schema API attack surface
    Given a new ZAP session
    When I spider "${schemaEndpoint}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers entity API attack surface
    Given a new ZAP session
    When I spider "${entitiesEndpoint}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers edge API attack surface
    Given a new ZAP session
    When I spider "${edgesEndpoint}"
    Then the spider should find at least 1 URLs

  Scenario: Spider discovers traversal API attack surface
    Given a new ZAP session
    When I spider "${traverseEndpoint}"
    Then the spider should find at least 1 URLs

  # ===========================================================================
  # PASSIVE VULNERABILITY SCANNING
  # Passive scans analyze traffic non-intrusively — safe for any environment.
  # They detect information leakage, insecure headers, cookie issues, and
  # other passive indicators without sending attack payloads.
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # Passive Scan — Health Endpoint (GET, unauthenticated)
  # Maps to: Health check endpoint returning Neo4j connectivity status.
  # Risk: Information leakage of internal infrastructure (Neo4j connection info).
  # ---------------------------------------------------------------------------

  Scenario: Passive scan on health endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${healthEndpoint}"
    And I run a passive scan on "${healthEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ---------------------------------------------------------------------------
  # Passive Scan — Schema Endpoint (GET/PUT, authenticated)
  # Maps to: Schema management scenarios (define, read, update, validation errors).
  # Risk: Schema definitions may leak workspace structure; validation error
  # messages could reveal internal implementation details.
  # ---------------------------------------------------------------------------

  Scenario: Passive scan on schema endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${schemaEndpoint}"
    And I run a passive scan on "${schemaEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ---------------------------------------------------------------------------
  # Passive Scan — Entity Endpoint (POST/GET/PUT/DELETE, authenticated)
  # Maps to: Entity CRUD scenarios (create, read, list, update, soft-delete).
  # Risk: Entity properties contain user-supplied data that could be crafted
  # for injection; property values are stored and later returned in responses.
  # ---------------------------------------------------------------------------

  Scenario: Passive scan on entity endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${entitiesEndpoint}"
    And I run a passive scan on "${entitiesEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ---------------------------------------------------------------------------
  # Passive Scan — Edge Endpoint (POST/GET/PUT/DELETE, authenticated)
  # Maps to: Edge CRUD scenarios (create, read, list, update, soft-delete).
  # Risk: Edge type names and property values are user-supplied and stored in
  # Neo4j — passive scan checks for information leakage in error responses.
  # ---------------------------------------------------------------------------

  Scenario: Passive scan on edge endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${edgesEndpoint}"
    And I run a passive scan on "${edgesEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ---------------------------------------------------------------------------
  # Passive Scan — Traversal Endpoint (GET, authenticated)
  # Maps to: Graph traversal scenarios (neighbors, paths, N-degree connections).
  # Risk: Traversal returns aggregated graph data; query parameters (depth,
  # direction, type) could leak internal graph structure in error messages.
  # ---------------------------------------------------------------------------

  Scenario: Passive scan on traversal endpoint finds no high-risk issues
    Given a new ZAP session
    When I spider "${traverseEndpoint}"
    And I run a passive scan on "${traverseEndpoint}"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found
    And I should see the alert details

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING — SQL / CYPHER INJECTION
  # The ERM uses Neo4j with Cypher queries under the hood and PostgreSQL for
  # schema storage. All user input MUST be parameterized — never interpolated
  # into Cypher or SQL strings. ZAP's SQL Injection scanner tests for common
  # injection patterns that would also catch Cypher injection via similar
  # error-based and boolean-based detection techniques.
  #
  # Maps to PRD: "Cypher query parameters always parameterized (never
  # string-interpolated)", "Entity type names and edge type names validated"
  # ===========================================================================

  # ---------------------------------------------------------------------------
  # SQL/Cypher Injection — Schema Endpoint
  # Vectors: workspace_id URL parameter, entity_types[].name, edge_types[].name,
  # property definitions in JSON body (PUT)
  # ---------------------------------------------------------------------------

  Scenario: No SQL Injection on schema endpoint
    Given a new ZAP session
    When I spider "${schemaEndpoint}"
    And I run an active scan on "${schemaEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  # ---------------------------------------------------------------------------
  # SQL/Cypher Injection — Entity Endpoint
  # Vectors: workspace_id and entity_id URL parameters, type field in JSON body,
  # property names and values in JSON body, query params (type, include_deleted,
  # limit, offset)
  # ---------------------------------------------------------------------------

  Scenario: No SQL Injection on entity endpoint
    Given a new ZAP session
    When I spider "${entitiesEndpoint}"
    And I run an active scan on "${entitiesEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  # ---------------------------------------------------------------------------
  # SQL/Cypher Injection — Edge Endpoint
  # Vectors: workspace_id and edge_id URL parameters, type/source_id/target_id
  # in JSON body, property names and values, query params
  # ---------------------------------------------------------------------------

  Scenario: No SQL Injection on edge endpoint
    Given a new ZAP session
    When I spider "${edgesEndpoint}"
    And I run an active scan on "${edgesEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  # ---------------------------------------------------------------------------
  # SQL/Cypher Injection — Traversal Endpoint
  # Vectors: workspace_id, entity_id, target_id URL parameters, query params
  # (start_id, depth, direction, type) — all fed into Cypher traversal queries.
  # This is the highest-risk surface for Cypher injection because traversal
  # queries are the most complex Cypher operations in the system.
  # ---------------------------------------------------------------------------

  Scenario: No SQL Injection on traversal endpoint
    Given a new ZAP session
    When I spider "${traverseEndpoint}"
    And I run an active scan on "${traverseEndpoint}"
    Then there should be no alerts of type "SQL Injection"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING — CROSS-SITE SCRIPTING (XSS)
  # Although the ERM is a JSON API (not rendering HTML), XSS tests verify that
  # user-supplied entity/edge property values and type names are not reflected
  # unsanitized in responses — especially in error messages that might include
  # the invalid input (e.g., "entity type 'X' not found").
  # ===========================================================================

  Scenario: No Cross-Site Scripting on schema endpoint
    Given a new ZAP session
    When I spider "${schemaEndpoint}"
    And I run an active scan on "${schemaEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: No Cross-Site Scripting on entity endpoint
    Given a new ZAP session
    When I spider "${entitiesEndpoint}"
    And I run an active scan on "${entitiesEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: No Cross-Site Scripting on edge endpoint
    Given a new ZAP session
    When I spider "${edgesEndpoint}"
    And I run an active scan on "${edgesEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  Scenario: No Cross-Site Scripting on traversal endpoint
    Given a new ZAP session
    When I spider "${traverseEndpoint}"
    And I run an active scan on "${traverseEndpoint}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING — PATH TRAVERSAL
  # URL path segments contain workspace_id (UUID), entity_id (UUID), and
  # target_id (UUID). Attackers may attempt ../../etc/passwd style traversal
  # through these parameters. The InputSanitizationPolicy validates UUID format,
  # but the active scan verifies this defense at the HTTP layer.
  #
  # Maps to auth.http.feature: cross-workspace access returns 404 (not 403)
  # to avoid leaking entity existence.
  # ===========================================================================

  Scenario: No path traversal on schema endpoint
    Given a new ZAP session
    When I spider "${schemaEndpoint}"
    And I run an active scan on "${schemaEndpoint}"
    Then there should be no alerts of type "Path Traversal"

  Scenario: No path traversal on entity endpoint
    Given a new ZAP session
    When I spider "${entitiesEndpoint}"
    And I run an active scan on "${entitiesEndpoint}"
    Then there should be no alerts of type "Path Traversal"

  Scenario: No path traversal on edge endpoint
    Given a new ZAP session
    When I spider "${edgesEndpoint}"
    And I run an active scan on "${edgesEndpoint}"
    Then there should be no alerts of type "Path Traversal"

  Scenario: No path traversal on traversal endpoint
    Given a new ZAP session
    When I spider "${traverseEndpoint}"
    And I run an active scan on "${traverseEndpoint}"
    Then there should be no alerts of type "Path Traversal"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING — REMOTE CODE EXECUTION
  # Entity type names, edge type names, and property values could be crafted
  # as shell commands if improperly handled during Neo4j query construction
  # or schema validation. The active scan verifies no OS command injection
  # vectors exist.
  # ===========================================================================

  Scenario: No remote code execution on schema endpoint
    Given a new ZAP session
    When I spider "${schemaEndpoint}"
    And I run an active scan on "${schemaEndpoint}"
    Then there should be no alerts of type "Remote OS Command Injection"

  Scenario: No remote code execution on entity endpoint
    Given a new ZAP session
    When I spider "${entitiesEndpoint}"
    And I run an active scan on "${entitiesEndpoint}"
    Then there should be no alerts of type "Remote OS Command Injection"

  Scenario: No remote code execution on edge endpoint
    Given a new ZAP session
    When I spider "${edgesEndpoint}"
    And I run an active scan on "${edgesEndpoint}"
    Then there should be no alerts of type "Remote OS Command Injection"

  # ===========================================================================
  # ACTIVE VULNERABILITY SCANNING — CROSS-WORKSPACE ISOLATION
  # Maps to auth.http.feature: "Entity from workspace A is not visible in
  # workspace B", "Edge from workspace A is not visible in workspace B",
  # "Traversal in workspace B does not return workspace A data"
  #
  # Tests: Scanning a cross-workspace endpoint for authorization bypass
  # vulnerabilities that could leak data between tenants.
  # ===========================================================================

  Scenario: No authorization bypass on cross-workspace entity access
    Given a new ZAP session
    Given I set variable "crossWorkspaceEntities" to "${baseUrl}/api/v1/workspaces/engineering/entities"
    When I spider "${crossWorkspaceEntities}"
    And I run an active scan on "${crossWorkspaceEntities}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Path Traversal"

  Scenario: No authorization bypass on cross-workspace edge access
    Given a new ZAP session
    Given I set variable "crossWorkspaceEdges" to "${baseUrl}/api/v1/workspaces/engineering/edges"
    When I spider "${crossWorkspaceEdges}"
    And I run an active scan on "${crossWorkspaceEdges}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Path Traversal"

  # ===========================================================================
  # BASELINE SCANS — Quick Combined Spider + Passive
  # Baseline scan = spider + passive scan combined. A fast first-pass check
  # for each major endpoint group before running slower active scans.
  # ===========================================================================

  Scenario: Baseline scan on health endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${healthEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on schema endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${schemaEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on entity endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${entitiesEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on edge endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${edgesEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  Scenario: Baseline scan on traversal endpoint passes
    Given a new ZAP session
    When I run a baseline scan on "${traverseEndpoint}"
    Then no high risk alerts should be found
    And alerts should not exceed risk level "Medium"

  # ===========================================================================
  # COMPREHENSIVE ACTIVE SCAN — Full ERM API
  # Maps to: All scenarios combined — deep active scan across all endpoints
  # with full assertion coverage for the complete API surface.
  # ===========================================================================

  Scenario: Comprehensive active scan on ERM API finds no high-risk vulnerabilities
    Given a new ZAP session
    When I spider "${healthEndpoint}"
    And I spider "${schemaEndpoint}"
    And I spider "${entitiesEndpoint}"
    And I spider "${edgesEndpoint}"
    And I spider "${traverseEndpoint}"
    And I run an active scan on "${schemaEndpoint}"
    And I run an active scan on "${entitiesEndpoint}"
    And I run an active scan on "${edgesEndpoint}"
    And I run an active scan on "${traverseEndpoint}"
    Then no high risk alerts should be found
    And I store the alerts as "comprehensiveScanAlerts"
    And I should see the alert details

  # ===========================================================================
  # SECURITY REPORTING — Audit Trail
  # Maps to: Compliance requirement — generate artifacts after full scan suite.
  # Produces both HTML (human-readable) and JSON (machine-parseable) reports
  # for security audit documentation.
  # ===========================================================================

  Scenario: Generate security audit report for ERM API
    Given a new ZAP session
    When I spider "${healthEndpoint}"
    And I spider "${schemaEndpoint}"
    And I spider "${entitiesEndpoint}"
    And I spider "${edgesEndpoint}"
    And I spider "${traverseEndpoint}"
    And I run a passive scan on "${healthEndpoint}"
    And I run a passive scan on "${schemaEndpoint}"
    And I run a passive scan on "${entitiesEndpoint}"
    And I run a passive scan on "${edgesEndpoint}"
    And I run a passive scan on "${traverseEndpoint}"
    And I run an active scan on "${schemaEndpoint}"
    And I run an active scan on "${entitiesEndpoint}"
    And I run an active scan on "${edgesEndpoint}"
    And I run an active scan on "${traverseEndpoint}"
    Then no high risk alerts should be found
    And there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "Cross Site Scripting (Persistent)"
    And there should be no alerts of type "Path Traversal"
    And there should be no alerts of type "Remote OS Command Injection"
    And I should see the alert details
    When I save the security report to "reports/erm-api-security-audit.html"
    And I save the security report as JSON to "reports/erm-api-security-audit.json"

  # ===========================================================================
  # NOTE: SSL/TLS certificate validation is skipped in the local test environment
  # because the test server runs over plain HTTP (http://localhost:4006).
  # In staging/production, SSL certificate checks should be added against the
  # HTTPS endpoint:
  #
  #   Scenario: SSL certificate is properly configured
  #     When I check SSL certificate for "https://erm.example.com"
  #     Then the SSL certificate should be valid
  #     And the SSL certificate should not expire within 30 days
  # ===========================================================================
