@security
Feature: Perme8 Dashboard Security Baseline
  As a security-conscious developer
  I want the Perme8 Dashboard to follow security best practices
  So that the dev-tool hub does not introduce vulnerabilities into the development environment

  Background:
    Given a new ZAP session

  Scenario: Dashboard has no high-risk vulnerabilities
    When I spider "${baseUrl}"
    And I run a passive scan on "${baseUrl}"
    Then no high risk alerts should be found

  Scenario: Dashboard security headers are present
    When I check "${baseUrl}" for security headers
    Then X-Frame-Options should be set to "SAMEORIGIN"
    And the security headers should include "X-Content-Type-Options"

  Scenario: Dashboard pages are free from common vulnerabilities
    When I spider "${baseUrl}"
    And I run a passive scan on "${baseUrl}"
    Then there should be no alerts of type "Cross Site Scripting (Reflected)"
    And there should be no alerts of type "SQL Injection"

  Scenario: Feature detail pages are included in security scan
    When I spider "${baseUrl}"
    Then the spider should find at least 2 URLs
    When I run a passive scan on "${baseUrl}"
    Then no high risk alerts should be found
    And I save the security report to "reports/perme8-dashboard-security.html"
