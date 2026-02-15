import { Then } from '@cucumber/cucumber'
import { expect } from '@playwright/test'
import { TestWorld } from '../../world/index.ts'
import { RiskLevel } from '../../../domain/value-objects/index.ts'
import type { RiskLevel as RiskLevelType } from '../../../domain/value-objects/index.ts'
import type { HeaderCheckResult, SslCheckResult, SpiderResult } from '../../../domain/entities/index.ts'

export interface AssertionContext {
  security: TestWorld['security']
  interpolate: TestWorld['interpolate']
  getVariable: TestWorld['getVariable']
  setVariable: TestWorld['setVariable']
  log: TestWorld['log']
}

// Spider Assertions
export function assertSpiderMinUrls(context: AssertionContext, minUrls: number): void {
  const result = context.getVariable<SpiderResult>('_spiderResult')
  expect(result.urlsFound).toBeGreaterThanOrEqual(minUrls)
}

// Alert Assertions (by risk)
export function assertNoHighRiskAlerts(context: AssertionContext): void {
  const alerts = context.security.getAlertsByRisk('High')
  expect(alerts).toHaveLength(0)
}

export function assertNoMediumOrHigherAlerts(context: AssertionContext): void {
  const allAlerts = context.security.alerts
  const mediumOrHigher = allAlerts.filter((a) =>
    RiskLevel.isAtLeast(a.risk, 'Medium'),
  )
  expect(mediumOrHigher).toHaveLength(0)
}

export function assertNoMediumOrHigherAlertsExcluding(
  context: AssertionContext,
  excludePattern: string,
): void {
  const allAlerts = context.security.alerts
  const pattern = context.interpolate(excludePattern)
  const mediumOrHigher = allAlerts.filter(
    (a) => RiskLevel.isAtLeast(a.risk, 'Medium') && !a.name.includes(pattern),
  )
  expect(mediumOrHigher).toHaveLength(0)
}

export function assertNoCriticalVulnerabilities(context: AssertionContext): void {
  const alerts = context.security.getAlertsByRisk('High')
  expect(alerts).toHaveLength(0)
}

export function assertAlertsNotExceedRisk(context: AssertionContext, maxRisk: string): void {
  const allAlerts = context.security.alerts
  const exceeding = allAlerts.filter((a) => {
    const riskOrder: Record<string, number> = { High: 3, Medium: 2, Low: 1, Informational: 0 }
    return (riskOrder[a.risk] ?? 0) > (riskOrder[maxRisk] ?? 0)
  })
  expect(exceeding).toHaveLength(0)
}

// Alert Assertions (by count)
export function assertAlertCount(context: AssertionContext, expectedCount: number): void {
  expect(context.security.alertCount).toBe(expectedCount)
}

export function assertAlertsLessThan(context: AssertionContext, maxAlerts: number): void {
  expect(context.security.alertCount).toBeLessThan(maxAlerts)
}

export function assertNoAlertsOfType(context: AssertionContext, alertType: string): void {
  const alerts = context.security.getAlertsByType(context.interpolate(alertType))
  expect(alerts).toHaveLength(0)
}

// Security Header Assertions
export function assertSecurityHeaderPresent(context: AssertionContext, headerName: string): void {
  const result = context.getVariable<HeaderCheckResult>('_headerCheckResult')
  expect(result.headers[headerName]).toBeDefined()
}

export function assertCspPresent(context: AssertionContext): void {
  const result = context.getVariable<HeaderCheckResult>('_headerCheckResult')
  expect(result.headers['Content-Security-Policy']).toBeDefined()
}

export function assertXFrameOptions(context: AssertionContext, expectedValue: string): void {
  const result = context.getVariable<HeaderCheckResult>('_headerCheckResult')
  expect(result.headers['X-Frame-Options']).toBe(context.interpolate(expectedValue))
}

export function assertHstsPresent(context: AssertionContext): void {
  const result = context.getVariable<HeaderCheckResult>('_headerCheckResult')
  expect(result.headers['Strict-Transport-Security']).toBeDefined()
}

// SSL Certificate Assertions
export function assertSslCertificateValid(context: AssertionContext): void {
  const result = context.getVariable<SslCheckResult>('_sslCheckResult')
  expect(result.valid).toBe(true)
}

export function assertSslCertificateNotExpiringSoon(context: AssertionContext, days: number): void {
  const result = context.getVariable<SslCheckResult>('_sslCheckResult')
  const expiresAt = new Date(result.expiresAt)
  const minDate = new Date(Date.now() + days * 24 * 60 * 60 * 1000)
  expect(expiresAt.getTime()).toBeGreaterThan(minDate.getTime())
}

// Detailed Inspection
export function logAlertDetails(context: AssertionContext): void {
  const alerts = context.security.alerts
  for (const alert of alerts) {
    context.log(`[${alert.risk}] ${alert.name}: ${alert.description}`)
    context.log(`  URL: ${alert.url}`)
    context.log(`  Solution: ${alert.solution}`)
  }
}

// Variable Storage
export function storeAlerts(context: AssertionContext, variableName: string): void {
  context.setVariable(variableName, context.security.alerts)
}

// Cucumber Registrations
Then<TestWorld>(
  'the spider should find at least {int} URLs',
  function (minUrls: number) {
    assertSpiderMinUrls(this, minUrls)
  },
)

Then<TestWorld>('no high risk alerts should be found', function () {
  assertNoHighRiskAlerts(this)
})

Then<TestWorld>('no medium or higher risk alerts should be found', function () {
  assertNoMediumOrHigherAlerts(this)
})

Then<TestWorld>(
  'no medium or higher risk alerts should be found excluding {string}',
  function (excludePattern: string) {
    assertNoMediumOrHigherAlertsExcluding(this, excludePattern)
  },
)

Then<TestWorld>('there should be no critical vulnerabilities', function () {
  assertNoCriticalVulnerabilities(this)
})

Then<TestWorld>('alerts should not exceed risk level {string}', function (maxRisk: string) {
  assertAlertsNotExceedRisk(this, maxRisk)
})

Then<TestWorld>('there should be {int} alerts', function (expectedCount: number) {
  assertAlertCount(this, expectedCount)
})

Then<TestWorld>('there should be less than {int} alerts', function (maxAlerts: number) {
  assertAlertsLessThan(this, maxAlerts)
})

Then<TestWorld>('there should be no alerts of type {string}', function (alertType: string) {
  assertNoAlertsOfType(this, alertType)
})

Then<TestWorld>('the security headers should include {string}', function (headerName: string) {
  assertSecurityHeaderPresent(this, headerName)
})

Then<TestWorld>('Content-Security-Policy should be present', function () {
  assertCspPresent(this)
})

Then<TestWorld>('X-Frame-Options should be set to {string}', function (expectedValue: string) {
  assertXFrameOptions(this, expectedValue)
})

Then<TestWorld>('Strict-Transport-Security should be present', function () {
  assertHstsPresent(this)
})

Then<TestWorld>('the SSL certificate should be valid', function () {
  assertSslCertificateValid(this)
})

Then<TestWorld>(
  'the SSL certificate should not expire within {int} days',
  function (days: number) {
    assertSslCertificateNotExpiringSoon(this, days)
  },
)

Then<TestWorld>('I should see the alert details', function () {
  logAlertDetails(this)
})

Then<TestWorld>('I store the alerts as {string}', function (variableName: string) {
  storeAlerts(this, variableName)
})
