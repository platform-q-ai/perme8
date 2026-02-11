import { test, expect, describe, beforeEach, spyOn, type Mock } from 'bun:test'
import type { SecurityAdapterConfig } from '../../src/application/config/index.ts'
import { ZapSecurityAdapter } from '../../src/infrastructure/adapters/security/ZapSecurityAdapter.ts'

// --- Mock state ---
let fetchSpy: ReturnType<typeof spyOn<typeof globalThis, 'fetch'>>
let fetchCallLog: { url: string; init?: RequestInit }[] = []
let fetchResponses: Array<{ ok: boolean; status: number; statusText: string; body: unknown; headers?: Record<string, string> }> = []
let fetchCallIndex = 0

// Tracks Bun.write calls
let bunWriteCalls: { path: string; data: unknown }[] = []

function pushResponse(body: unknown, opts?: { ok?: boolean; status?: number; statusText?: string; headers?: Record<string, string> }) {
  fetchResponses.push({
    ok: opts?.ok ?? true,
    status: opts?.status ?? 200,
    statusText: opts?.statusText ?? 'OK',
    body,
    headers: opts?.headers,
  })
}

function makeMockResponse(entry: (typeof fetchResponses)[number]): Response {
  const headersInit = new Headers(entry.headers ?? {})
  return {
    ok: entry.ok,
    status: entry.status,
    statusText: entry.statusText,
    headers: headersInit,
    json: async () => entry.body,
    text: async () => (typeof entry.body === 'string' ? entry.body : JSON.stringify(entry.body)),
    arrayBuffer: async () => new TextEncoder().encode(typeof entry.body === 'string' ? entry.body : JSON.stringify(entry.body)).buffer,
  } as unknown as Response
}

const defaultConfig: SecurityAdapterConfig = {
  zapUrl: 'http://localhost:8080',
  zapApiKey: 'test-api-key',
  pollDelayMs: 0, // Eliminate real setTimeout delays in tests
}

function createAdapter(overrides?: Partial<SecurityAdapterConfig>) {
  return new ZapSecurityAdapter({ ...defaultConfig, ...overrides })
}

describe('ZapSecurityAdapter', () => {
  beforeEach(() => {
    fetchCallLog = []
    fetchResponses = []
    fetchCallIndex = 0
    bunWriteCalls = []

    fetchSpy = spyOn(globalThis, 'fetch').mockImplementation((async (input: string | URL | Request, init?: RequestInit) => {
      const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url
      fetchCallLog.push({ url, init })
      const entry = fetchResponses[fetchCallIndex]
      if (!entry) throw new Error(`No mock response configured for fetch call #${fetchCallIndex} to ${url}`)
      fetchCallIndex++
      return makeMockResponse(entry)
    }) as typeof fetch)

    // Mock Bun.write
    spyOn(Bun, 'write').mockImplementation(async (path: any, data: any) => {
      bunWriteCalls.push({ path: String(path), data })
      return 0
    }) as any
  })

  // 1
  test('constructor stores config (zapUrl, apiKey)', () => {
    const adapter = createAdapter()

    expect(adapter.config.zapUrl).toBe('http://localhost:8080')
    expect(adapter.config.zapApiKey).toBe('test-api-key')
  })

  // 2
  test('spider starts spider scan via API', async () => {
    // start scan
    pushResponse({ scan: '1' })
    // status check -> complete immediately
    pushResponse({ status: '100' })
    // results
    pushResponse({ results: ['http://example.com', 'http://example.com/about'] })

    const adapter = createAdapter()
    await adapter.spider('http://example.com')

    const startUrl = fetchCallLog[0]!.url
    expect(startUrl).toContain('/JSON/spider/action/scan/')
    expect(startUrl).toContain('url=http')
  })

  // 3
  test('spider polls until completion', async () => {
    // start scan
    pushResponse({ scan: '1' })
    // poll #1: not complete
    pushResponse({ status: '50' })
    // poll #2: complete
    pushResponse({ status: '100' })
    // results
    pushResponse({ results: ['http://example.com'] })

    const adapter = createAdapter()
    await adapter.spider('http://example.com')

    // Two status poll calls
    const statusCalls = fetchCallLog.filter((c) => c.url.includes('/JSON/spider/view/status/'))
    expect(statusCalls).toHaveLength(2)
  })

  // 4
  test('spider returns urlsFound count', async () => {
    pushResponse({ scan: '1' })
    pushResponse({ status: '100' })
    pushResponse({ results: ['http://a.com', 'http://b.com', 'http://c.com'] })

    const adapter = createAdapter()
    const result = await adapter.spider('http://example.com')

    expect(result.urlsFound).toBe(3)
    expect(result.duration).toBeGreaterThanOrEqual(0)
  })

  // 5
  test('activeScan starts scan via API', async () => {
    // start scan
    pushResponse({ scan: '42' })
    // status -> complete
    pushResponse({ status: '100' })
    // refreshAlerts
    pushResponse({ alerts: [] })

    const adapter = createAdapter()
    await adapter.activeScan('http://example.com')

    const startUrl = fetchCallLog[0]!.url
    expect(startUrl).toContain('/JSON/ascan/action/scan/')
    expect(startUrl).toContain('url=http')
  })

  // 6
  test('activeScan polls at configured intervals', async () => {
    // start scan
    pushResponse({ scan: '1' })
    // poll #1: not done
    pushResponse({ status: '50' })
    // poll #2: done
    pushResponse({ status: '100' })
    // refreshAlerts
    pushResponse({ alerts: [] })

    const adapter = createAdapter()
    await adapter.activeScan('http://example.com')

    // Two status poll calls verify the polling loop executed
    const statusCalls = fetchCallLog.filter((c) => c.url.includes('/JSON/ascan/view/status/'))
    expect(statusCalls).toHaveLength(2)
  })

  // 7
  test('activeScan refreshes alerts on completion', async () => {
    pushResponse({ scan: '1' })
    pushResponse({ status: '100' })
    pushResponse({
      alerts: [
        {
          name: 'XSS',
          risk: 'High',
          confidence: 'High',
          description: 'Cross-site scripting',
          url: 'http://example.com',
          solution: 'Encode output',
          reference: '',
          cweid: '79',
          wascid: '8',
        },
      ],
    })

    const adapter = createAdapter()
    const result = await adapter.activeScan('http://example.com')

    expect(result.alertCount).toBe(1)
    expect(adapter.alerts).toHaveLength(1)
    expect(adapter.alerts[0]!.name).toBe('XSS')
    expect(adapter.alerts[0]!.risk).toBe('High')
  })

  // 8
  test('passiveScan waits for queue to drain', async () => {
    // First check: records remaining
    pushResponse({ recordsToScan: '5' })
    // Second check: still remaining
    pushResponse({ recordsToScan: '2' })
    // Third check: done
    pushResponse({ recordsToScan: '0' })
    // refreshAlerts
    pushResponse({ alerts: [] })

    const adapter = createAdapter()
    const result = await adapter.passiveScan('http://example.com')

    const pscanCalls = fetchCallLog.filter((c) => c.url.includes('/JSON/pscan/view/recordsToScan/'))
    expect(pscanCalls).toHaveLength(3)
    expect(result.progress).toBe(100)
  })

  // 9
  test('alerts getter returns cached alerts', async () => {
    pushResponse({ scan: '1' })
    pushResponse({ status: '100' })
    pushResponse({
      alerts: [
        { name: 'SQL Injection', risk: 'High', confidence: 'Medium', description: 'desc', url: 'http://x.com', solution: 'fix', reference: '', cweid: '89', wascid: '' },
        { name: 'Info Disclosure', risk: 'Low', confidence: 'Low', description: 'desc', url: 'http://x.com', solution: 'fix', reference: '', cweid: '200', wascid: '' },
      ],
    })

    const adapter = createAdapter()
    await adapter.activeScan('http://example.com')

    expect(adapter.alerts).toHaveLength(2)
    expect(adapter.alertCount).toBe(2)
  })

  // 10
  test('getAlertsByRisk filters by risk level', async () => {
    pushResponse({ scan: '1' })
    pushResponse({ status: '100' })
    pushResponse({
      alerts: [
        { name: 'XSS', risk: 'High', confidence: 'High', description: '', url: '', solution: '', reference: '', cweid: '79', wascid: '' },
        { name: 'Cookie', risk: 'Low', confidence: 'Medium', description: '', url: '', solution: '', reference: '', cweid: '614', wascid: '' },
        { name: 'SQLi', risk: 'High', confidence: 'High', description: '', url: '', solution: '', reference: '', cweid: '89', wascid: '' },
      ],
    })

    const adapter = createAdapter()
    await adapter.activeScan('http://example.com')

    const highAlerts = adapter.getAlertsByRisk('High')
    expect(highAlerts).toHaveLength(2)
    expect(highAlerts.every((a) => a.risk === 'High')).toBe(true)

    const lowAlerts = adapter.getAlertsByRisk('Low')
    expect(lowAlerts).toHaveLength(1)
    expect(lowAlerts[0]!.name).toBe('Cookie')
  })

  // 11
  test('getAlertsByRisk returns empty for no matches', async () => {
    pushResponse({ scan: '1' })
    pushResponse({ status: '100' })
    pushResponse({
      alerts: [
        { name: 'XSS', risk: 'High', confidence: 'High', description: '', url: '', solution: '', reference: '', cweid: '79', wascid: '' },
      ],
    })

    const adapter = createAdapter()
    await adapter.activeScan('http://example.com')

    const mediumAlerts = adapter.getAlertsByRisk('Medium')
    expect(mediumAlerts).toHaveLength(0)
  })

  // 12
  test('checkSecurityHeaders fetches and checks 7 headers', async () => {
    pushResponse({}, {
      headers: {
        'Content-Security-Policy': "default-src 'self'",
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'DENY',
        'Strict-Transport-Security': 'max-age=31536000',
        'X-XSS-Protection': '1; mode=block',
        'Referrer-Policy': 'no-referrer',
        'Permissions-Policy': 'geolocation=()',
      },
    })

    const adapter = createAdapter()
    const result = await adapter.checkSecurityHeaders('http://example.com')

    expect(result.missing).toHaveLength(0)
    expect(result.issues).toHaveLength(0)
    expect(result.headers['Content-Security-Policy']).toBe("default-src 'self'")
    expect(result.headers['X-Content-Type-Options']).toBe('nosniff')
    expect(result.headers['Strict-Transport-Security']).toBe('max-age=31536000')
  })

  // 13
  test('checkSecurityHeaders reports missing headers', async () => {
    pushResponse({}, {
      headers: {
        'Content-Security-Policy': "default-src 'self'",
        'X-Content-Type-Options': 'nosniff',
      },
    })

    const adapter = createAdapter()
    const result = await adapter.checkSecurityHeaders('http://example.com')

    expect(result.missing).toContain('X-Frame-Options')
    expect(result.missing).toContain('Strict-Transport-Security')
    expect(result.missing).toContain('X-XSS-Protection')
    expect(result.missing).toContain('Referrer-Policy')
    expect(result.missing).toContain('Permissions-Policy')
    expect(result.missing).toHaveLength(5)
    expect(result.issues).toHaveLength(5)
    result.issues.forEach((issue) => {
      expect(issue).toMatch(/^Missing security header: /)
    })
  })

  // 14
  test('checkSecurityHeaders reports all present', async () => {
    pushResponse({}, {
      headers: {
        'Content-Security-Policy': "default-src 'self'",
        'X-Content-Type-Options': 'nosniff',
        'X-Frame-Options': 'SAMEORIGIN',
        'Strict-Transport-Security': 'max-age=63072000',
        'X-XSS-Protection': '1',
        'Referrer-Policy': 'strict-origin',
        'Permissions-Policy': 'camera=()',
      },
    })

    const adapter = createAdapter()
    const result = await adapter.checkSecurityHeaders('http://example.com')

    expect(result.missing).toHaveLength(0)
    expect(result.issues).toHaveLength(0)
    expect(Object.keys(result.headers).length).toBeGreaterThanOrEqual(7)
  })

  // 15
  test('checkSslCertificate validates HTTPS URL', async () => {
    pushResponse({}, { ok: true, status: 200, statusText: 'OK' })

    const adapter = createAdapter()
    const result = await adapter.checkSslCertificate('https://example.com')

    expect(result.valid).toBe(true)
    expect(result.issues).toHaveLength(0)
    expect(result.expiresAt.getTime()).toBeGreaterThan(Date.now())
  })

  // 16
  test('checkSslCertificate reports invalid cert', async () => {
    // Mock fetch to throw an error (simulating SSL failure)
    fetchResponses.push({
      ok: false,
      status: 0,
      statusText: '',
      body: null,
      headers: {},
    })
    // Override the mock for this specific call to throw
    fetchSpy.mockImplementationOnce((() => {
      throw new Error('SSL certificate has expired')
    }) as unknown as typeof fetch)

    const adapter = createAdapter()
    const result = await adapter.checkSslCertificate('https://expired.example.com')

    expect(result.valid).toBe(false)
    expect(result.issues).toContain('SSL certificate has expired')
  })

  // 17
  test('generateHtmlReport fetches and writes report', async () => {
    const reportHtml = '<html><body><h1>ZAP Report</h1></body></html>'
    pushResponse(reportHtml)

    const adapter = createAdapter()
    await adapter.generateHtmlReport('/tmp/report.html')

    // Verify the ZAP API was called
    expect(fetchCallLog[0]!.url).toContain('/OTHER/core/other/htmlreport/')

    // Verify Bun.write was called
    expect(bunWriteCalls).toHaveLength(1)
    expect(bunWriteCalls[0]!.path).toBe('/tmp/report.html')
  })

  // 18
  test('newSession creates fresh session', async () => {
    // First, populate alerts via an active scan
    pushResponse({ scan: '1' })
    pushResponse({ status: '100' })
    pushResponse({
      alerts: [
        { name: 'XSS', risk: 'High', confidence: 'High', description: '', url: '', solution: '', reference: '', cweid: '79', wascid: '' },
      ],
    })

    const adapter = createAdapter()
    await adapter.activeScan('http://example.com')
    expect(adapter.alertCount).toBe(1)

    // Now call newSession
    pushResponse({})
    await adapter.newSession()

    // Verify API call
    const newSessionCall = fetchCallLog.find((c) => c.url.includes('/JSON/core/action/newSession/'))
    expect(newSessionCall).toBeDefined()

    // Alerts should be cleared
    expect(adapter.alerts).toHaveLength(0)
    expect(adapter.alertCount).toBe(0)
  })

  // 19
  test('dispose is a no-op', async () => {
    const adapter = createAdapter()
    await adapter.dispose()

    // Should not throw and should not make any fetch calls
    expect(fetchCallLog).toHaveLength(0)
  })

  // 20
  test('zapRequest includes API key in params', async () => {
    pushResponse({ scan: '1' })
    pushResponse({ status: '100' })
    pushResponse({ results: [] })

    const adapter = createAdapter({ zapApiKey: 'my-secret-key' })
    await adapter.spider('http://example.com')

    // Every fetch call should include the apikey param
    for (const call of fetchCallLog) {
      expect(call.url).toContain('apikey=my-secret-key')
    }
  })

  // 21
  test('zapRequest handles API errors', async () => {
    pushResponse({ error: 'Forbidden' }, { ok: false, status: 403, statusText: 'Forbidden' })

    const adapter = createAdapter()
    await expect(adapter.spider('http://example.com')).rejects.toThrow(
      'ZAP API request failed: 403 Forbidden',
    )
  })
})
