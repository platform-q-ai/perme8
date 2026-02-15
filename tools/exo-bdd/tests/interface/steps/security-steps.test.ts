import { test, expect, describe, beforeEach, mock } from 'bun:test'
import { VariableService } from '../../../src/application/services/VariableService.ts'
import { InterpolationService } from '../../../src/application/services/InterpolationService.ts'
import { RiskLevel } from '../../../src/domain/value-objects/RiskLevel.ts'
import type {
  SecurityAlert,
  ScanResult,
  SpiderResult,
  HeaderCheckResult,
  SslCheckResult,
} from '../../../src/domain/entities/index.ts'
import type { SecurityAdapterConfig } from '../../../src/application/config/index.ts'

// Mock Cucumber so the step-file-level Given/When/Then registrations are no-ops
mock.module('@cucumber/cucumber', () => ({
  Given: mock(),
  When: mock(),
  Then: mock(),
  Before: mock(),
  After: mock(),
  BeforeAll: mock(),
  AfterAll: mock(),
  setWorldConstructor: mock(),
  World: class MockWorld { constructor() {} },
  Status: { FAILED: 'FAILED', PASSED: 'PASSED' },
  default: {},
}))

// Mock @playwright/test so assertion handlers use a working expect
mock.module('@playwright/test', () => ({
  expect,
  default: {},
}))

// Dynamic imports after mocks so Cucumber registrations run harmlessly
const {
  newZapSession,
  spiderUrl,
  runActiveScan,
  runPassiveScan,
  checkSecurityHeaders,
  checkSslCertificate,
  saveSecurityReportHtml,
} = await import('../../../src/interface/steps/security/scanning.steps.ts')
const {
  assertNoHighRiskAlerts,
  assertNoMediumOrHigherAlerts,
  assertNoMediumOrHigherAlertsExcluding,
  assertAlertCount,
  assertAlertsLessThan,
  assertSecurityHeaderPresent,
  assertCspPresent,
  assertSslCertificateValid,
  assertSpiderMinUrls,
  storeAlerts,
} = await import('../../../src/interface/steps/security/assertions.steps.ts')

/**
 * Tests for security step definition logic (scanning, assertions).
 *
 * These tests import and invoke the actual exported handler functions from
 * the refactored step definition files, passing a mock world that satisfies
 * the context interfaces.
 */

// ─── Helpers ──────────────────────────────────────────────────────────────────

function makeAlert(overrides: Partial<SecurityAlert> = {}): SecurityAlert {
  return {
    name: overrides.name ?? 'Cross-Site Scripting',
    risk: overrides.risk ?? 'Low',
    confidence: overrides.confidence ?? 'Medium',
    description: overrides.description ?? 'XSS vulnerability found',
    url: overrides.url ?? 'https://example.com/page',
    solution: overrides.solution ?? 'Encode output',
    reference: overrides.reference ?? 'https://owasp.org/xss',
    cweid: overrides.cweid ?? '79',
    wascid: overrides.wascid ?? '8',
  }
}

function makeScanResult(overrides: Partial<ScanResult> = {}): ScanResult {
  return {
    alertCount: overrides.alertCount ?? 0,
    duration: overrides.duration ?? 1500,
    progress: overrides.progress ?? 100,
  }
}

function makeSpiderResult(overrides: Partial<SpiderResult> = {}): SpiderResult {
  return {
    urlsFound: overrides.urlsFound ?? 10,
    duration: overrides.duration ?? 2000,
  }
}

function makeHeaderCheckResult(headers: Record<string, string> = {}): HeaderCheckResult {
  return {
    headers,
    missing: [],
    issues: [],
  }
}

function makeSslCheckResult(overrides: Partial<SslCheckResult> = {}): SslCheckResult {
  return {
    valid: overrides.valid ?? true,
    expiresAt: overrides.expiresAt ?? new Date(Date.now() + 90 * 24 * 60 * 60 * 1000),
    issuer: overrides.issuer ?? 'Let\'s Encrypt',
    issues: overrides.issues ?? [],
  }
}

interface MockSecurityPort {
  newSession: ReturnType<typeof mock>
  spider: ReturnType<typeof mock>
  activeScan: ReturnType<typeof mock>
  passiveScan: ReturnType<typeof mock>
  ajaxSpider: ReturnType<typeof mock>
  checkSecurityHeaders: ReturnType<typeof mock>
  checkSslCertificate: ReturnType<typeof mock>
  generateHtmlReport: ReturnType<typeof mock>
  generateJsonReport: ReturnType<typeof mock>
  getAlertsByRisk: ReturnType<typeof mock>
  getAlertsByConfidence: ReturnType<typeof mock>
  getAlertsByType: ReturnType<typeof mock>
  dispose: ReturnType<typeof mock>
  config: SecurityAdapterConfig
  alerts: SecurityAlert[]
  alertCount: number
}

function createMockWorld() {
  const variableService = new VariableService()
  const interpolationService = new InterpolationService(variableService)

  const security: MockSecurityPort = {
    newSession: mock(() => Promise.resolve()),
    spider: mock(() => Promise.resolve(makeSpiderResult())),
    activeScan: mock(() => Promise.resolve(makeScanResult())),
    passiveScan: mock(() => Promise.resolve(makeScanResult())),
    ajaxSpider: mock(() => Promise.resolve(makeSpiderResult())),
    checkSecurityHeaders: mock(() => Promise.resolve(makeHeaderCheckResult())),
    checkSslCertificate: mock(() => Promise.resolve(makeSslCheckResult())),
    generateHtmlReport: mock(() => Promise.resolve()),
    generateJsonReport: mock(() => Promise.resolve()),
    getAlertsByRisk: mock(() => [] as SecurityAlert[]),
    getAlertsByConfidence: mock(() => [] as SecurityAlert[]),
    getAlertsByType: mock(() => [] as SecurityAlert[]),
    dispose: mock(() => Promise.resolve()),
    config: { zapUrl: 'http://localhost:8080' },
    alerts: [],
    alertCount: 0,
  }

  return {
    security,
    setVariable: (name: string, value: unknown) => variableService.set(name, value),
    getVariable: <T>(name: string): T => variableService.get<T>(name),
    hasVariable: (name: string) => variableService.has(name),
    interpolate: (text: string) => interpolationService.interpolate(text),
    log: (_message: string) => {},
  }
}

type MockWorld = ReturnType<typeof createMockWorld>

// ─── Tests ────────────────────────────────────────────────────────────────────

describe('Security Steps', () => {
  let world: MockWorld

  beforeEach(() => {
    world = createMockWorld()
  })

  // ═══════════════════════════════════════════════════════════════════════════
  // scanning.steps.ts
  // ═══════════════════════════════════════════════════════════════════════════

  describe('Scanning Steps', () => {
    // ── Test 1: 'a new ZAP session' calls security.newSession ──────────────
    test('a new ZAP session calls security.newSession', async () => {
      await newZapSession(world)

      expect(world.security.newSession).toHaveBeenCalledTimes(1)
    })

    // ── Test 2: 'I spider' calls security.spider ───────────────────────────
    test('I spider calls security.spider with interpolated URL', async () => {
      const spiderResult = makeSpiderResult({ urlsFound: 25 })
      world.security.spider.mockResolvedValueOnce(spiderResult)

      await spiderUrl(world, 'https://example.com')

      expect(world.security.spider).toHaveBeenCalledWith('https://example.com')
    })

    // ── Test 3: 'I spider' stores result as _spiderResult ──────────────────
    test('I spider stores result as _spiderResult', async () => {
      const spiderResult = makeSpiderResult({ urlsFound: 15, duration: 3000 })
      world.security.spider.mockResolvedValueOnce(spiderResult)

      await spiderUrl(world, 'https://example.com')

      const stored = world.getVariable<SpiderResult>('_spiderResult')
      expect(stored.urlsFound).toBe(15)
      expect(stored.duration).toBe(3000)
    })

    // ── Test 4: 'I run an active scan on' calls security.activeScan ────────
    test('I run an active scan on calls security.activeScan', async () => {
      const scanResult = makeScanResult({ alertCount: 3 })
      world.security.activeScan.mockResolvedValueOnce(scanResult)

      await runActiveScan(world, 'https://example.com')

      expect(world.security.activeScan).toHaveBeenCalledWith('https://example.com')
    })

    // ── Test 5: 'I run an active scan on' stores result as _scanResult ─────
    test('I run an active scan on stores result as _scanResult', async () => {
      const scanResult = makeScanResult({ alertCount: 7, duration: 5000 })
      world.security.activeScan.mockResolvedValueOnce(scanResult)

      await runActiveScan(world, 'https://example.com')

      const stored = world.getVariable<ScanResult>('_scanResult')
      expect(stored.alertCount).toBe(7)
      expect(stored.duration).toBe(5000)
    })

    // ── Test 6: 'I run a passive scan on' calls security.passiveScan ───────
    test('I run a passive scan on calls security.passiveScan', async () => {
      const scanResult = makeScanResult({ alertCount: 1 })
      world.security.passiveScan.mockResolvedValueOnce(scanResult)

      await runPassiveScan(world, 'https://example.com/api')

      expect(world.security.passiveScan).toHaveBeenCalledWith('https://example.com/api')
    })

    // ── Test 7: 'I check {string} for security headers' calls checkSecurityHeaders
    test('I check for security headers calls checkSecurityHeaders', async () => {
      const headerResult = makeHeaderCheckResult({
        'X-Frame-Options': 'DENY',
        'Content-Security-Policy': "default-src 'self'",
      })
      world.security.checkSecurityHeaders.mockResolvedValueOnce(headerResult)

      await checkSecurityHeaders(world, 'https://example.com')

      expect(world.security.checkSecurityHeaders).toHaveBeenCalledWith('https://example.com')
    })

    // ── Test 8: 'I check SSL certificate for {string}' calls checkSslCertificate
    test('I check SSL certificate calls checkSslCertificate', async () => {
      const sslResult = makeSslCheckResult({ valid: true })
      world.security.checkSslCertificate.mockResolvedValueOnce(sslResult)

      await checkSslCertificate(world, 'https://example.com')

      expect(world.security.checkSslCertificate).toHaveBeenCalledWith('https://example.com')
    })

    // ── Test 9: 'I save the security report to' calls generateHtmlReport ───
    test('I save the security report to calls generateHtmlReport', async () => {
      await saveSecurityReportHtml(world, '/tmp/report.html')

      expect(world.security.generateHtmlReport).toHaveBeenCalledWith('/tmp/report.html')
    })
  })

  // ═══════════════════════════════════════════════════════════════════════════
  // assertions.steps.ts
  // ═══════════════════════════════════════════════════════════════════════════

  describe('Assertion Steps', () => {
    // ── Test 10: 'no high risk alerts should be found' passes when none ────
    test('no high risk alerts should be found passes when none', () => {
      world.security.getAlertsByRisk.mockReturnValueOnce([])

      assertNoHighRiskAlerts(world)
    })

    // ── Test 11: 'no high risk alerts' fails when found ────────────────────
    test('no high risk alerts should be found fails when high alerts exist', () => {
      const highAlerts = [makeAlert({ risk: 'High', name: 'SQL Injection' })]
      world.security.getAlertsByRisk.mockReturnValueOnce(highAlerts)

      expect(() => {
        assertNoHighRiskAlerts(world)
      }).toThrow()
    })

    // ── Test 12: 'no medium or higher risk alerts' passes ──────────────────
    test('no medium or higher risk alerts passes when only low/info', () => {
      world.security.alerts = [
        makeAlert({ risk: 'Low' }),
        makeAlert({ risk: 'Informational' }),
      ]

      assertNoMediumOrHigherAlerts(world)
    })

    // ── Test 13: 'no medium or higher risk alerts' fails ───────────────────
    test('no medium or higher risk alerts fails when medium alerts exist', () => {
      world.security.alerts = [
        makeAlert({ risk: 'Medium', name: 'Cookie Without Secure Flag' }),
        makeAlert({ risk: 'Low' }),
      ]

      expect(() => {
        assertNoMediumOrHigherAlerts(world)
      }).toThrow()
    })

    // ── Test 13a: 'no medium or higher excluding' passes when all medium alerts match exclusion
    test('no medium or higher excluding passes when excluded pattern matches all medium alerts', () => {
      world.security.alerts = [
        makeAlert({ risk: 'Medium', name: 'CSP: script-src unsafe-inline' }),
        makeAlert({ risk: 'Medium', name: 'CSP: style-src unsafe-inline' }),
        makeAlert({ risk: 'Low', name: 'Cookie Without Secure Flag' }),
      ]

      assertNoMediumOrHigherAlertsExcluding(world, 'CSP:')
    })

    // ── Test 13b: 'no medium or higher excluding' fails when non-excluded medium alerts remain
    test('no medium or higher excluding fails when non-excluded medium alerts remain', () => {
      world.security.alerts = [
        makeAlert({ risk: 'Medium', name: 'CSP: script-src unsafe-inline' }),
        makeAlert({ risk: 'Medium', name: 'Missing Anti-clickjacking Header' }),
        makeAlert({ risk: 'Low', name: 'Cookie Without Secure Flag' }),
      ]

      expect(() => {
        assertNoMediumOrHigherAlertsExcluding(world, 'CSP:')
      }).toThrow()
    })

    // ── Test 13c: 'no medium or higher excluding' passes when no medium alerts at all
    test('no medium or higher excluding passes when no medium alerts exist', () => {
      world.security.alerts = [
        makeAlert({ risk: 'Low', name: 'Something Low' }),
        makeAlert({ risk: 'Informational', name: 'Info Alert' }),
      ]

      assertNoMediumOrHigherAlertsExcluding(world, 'CSP:')
    })

    // ── Test 13d: 'no medium or higher excluding' supports comma-separated patterns
    test('no medium or higher excluding supports comma-separated patterns', () => {
      world.security.alerts = [
        makeAlert({ risk: 'Medium', name: 'CSP: script-src unsafe-inline' }),
        makeAlert({ risk: 'Medium', name: 'Absence of Anti-CSRF Tokens' }),
        makeAlert({ risk: 'Low', name: 'Cookie Without Secure Flag' }),
      ]

      assertNoMediumOrHigherAlertsExcluding(world, 'CSP:, Absence of Anti-CSRF')
    })

    // ── Test 13e: comma-separated fails when non-excluded alert remains
    test('no medium or higher excluding with comma-separated fails when non-excluded remains', () => {
      world.security.alerts = [
        makeAlert({ risk: 'Medium', name: 'CSP: script-src unsafe-inline' }),
        makeAlert({ risk: 'Medium', name: 'Absence of Anti-CSRF Tokens' }),
        makeAlert({ risk: 'Medium', name: 'Missing Anti-clickjacking Header' }),
      ]

      expect(() => {
        assertNoMediumOrHigherAlertsExcluding(world, 'CSP:, Absence of Anti-CSRF')
      }).toThrow()
    })

    // ── Test 14: 'there should be N alerts' passes for exact match ─────────
    test('there should be N alerts passes for exact count', () => {
      world.security.alertCount = 3

      assertAlertCount(world, 3)
    })

    // ── Test 15: 'there should be less than N alerts' passes ───────────────
    test('there should be less than N alerts passes when below threshold', () => {
      world.security.alertCount = 2

      assertAlertsLessThan(world, 5)
    })

    // ── Test 16: 'the security headers should include' passes ──────────────
    test('the security headers should include passes when header present', () => {
      const headerResult = makeHeaderCheckResult({
        'X-Frame-Options': 'DENY',
        'X-Content-Type-Options': 'nosniff',
      })
      world.setVariable('_headerCheckResult', headerResult)

      assertSecurityHeaderPresent(world, 'X-Frame-Options')
    })

    // ── Test 17: 'the security headers should include' fails when missing ──
    test('the security headers should include fails when header missing', () => {
      const headerResult = makeHeaderCheckResult({
        'X-Frame-Options': 'DENY',
      })
      world.setVariable('_headerCheckResult', headerResult)

      expect(() => {
        assertSecurityHeaderPresent(world, 'Content-Security-Policy')
      }).toThrow()
    })

    // ── Test 18: 'Content-Security-Policy should be present' passes ────────
    test('Content-Security-Policy should be present passes when header exists', () => {
      const headerResult = makeHeaderCheckResult({
        'Content-Security-Policy': "default-src 'self'",
      })
      world.setVariable('_headerCheckResult', headerResult)

      assertCspPresent(world)
    })

    // ── Test 19: 'the SSL certificate should be valid' passes ──────────────
    test('the SSL certificate should be valid passes when valid', () => {
      const sslResult = makeSslCheckResult({ valid: true })
      world.setVariable('_sslCheckResult', sslResult)

      assertSslCertificateValid(world)
    })

    // ── Test 20: 'the SSL certificate should be valid' fails ───────────────
    test('the SSL certificate should be valid fails when invalid', () => {
      const sslResult = makeSslCheckResult({ valid: false })
      world.setVariable('_sslCheckResult', sslResult)

      expect(() => {
        assertSslCertificateValid(world)
      }).toThrow()
    })

    // ── Test 21: 'the spider should find at least N URLs' passes ───────────
    test('the spider should find at least N URLs passes when enough found', () => {
      const spiderResult = makeSpiderResult({ urlsFound: 20 })
      world.setVariable('_spiderResult', spiderResult)

      assertSpiderMinUrls(world, 10)
    })

    // ── Test 22: 'the spider should find at least N URLs' fails ────────────
    test('the spider should find at least N URLs fails when too few', () => {
      const spiderResult = makeSpiderResult({ urlsFound: 3 })
      world.setVariable('_spiderResult', spiderResult)

      expect(() => {
        assertSpiderMinUrls(world, 10)
      }).toThrow()
    })

    // ── Test 23: 'I store the alerts as' stores alerts variable ────────────
    test('I store the alerts as stores alerts in variable', () => {
      const alerts = [
        makeAlert({ name: 'XSS', risk: 'High' }),
        makeAlert({ name: 'CSRF', risk: 'Medium' }),
      ]
      world.security.alerts = alerts

      storeAlerts(world, 'foundAlerts')

      const stored = world.getVariable<SecurityAlert[]>('foundAlerts')
      expect(stored).toHaveLength(2)
      expect(stored[0]!.name).toBe('XSS')
      expect(stored[1]!.risk).toBe('Medium')
    })
  })
})
