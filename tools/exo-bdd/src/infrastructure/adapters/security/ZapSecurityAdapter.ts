import type { SecurityPort } from '../../../application/ports/index.ts'
import type { SecurityAdapterConfig } from '../../../application/config/index.ts'
import type {
  SecurityAlert,
  ConfidenceLevel,
  ScanResult,
  SpiderResult,
  HeaderCheckResult,
  SslCheckResult,
} from '../../../domain/entities/index.ts'
import type { RiskLevel } from '../../../domain/value-objects/index.ts'

export class ZapSecurityAdapter implements SecurityPort {
  private _alerts: SecurityAlert[] = []
  private readonly baseUrl: string
  private readonly apiKey: string
  private readonly pollDelayMs: number

  constructor(readonly config: SecurityAdapterConfig) {
    this.baseUrl = config.zapUrl.replace(/\/$/, '')
    this.apiKey = config.zapApiKey ?? ''
    this.pollDelayMs = config.pollDelayMs ?? -1 // -1 = use per-method defaults
  }

  private async zapRequest<T>(endpoint: string, params: Record<string, string> = {}): Promise<T> {
    const url = new URL(`${this.baseUrl}${endpoint}`)
    url.searchParams.set('apikey', this.apiKey)
    Object.entries(params).forEach(([k, v]) => url.searchParams.set(k, v))

    const response = await fetch(url.toString())

    if (!response.ok) {
      throw new Error(`ZAP API request failed: ${response.status} ${response.statusText}`)
    }

    return (await response.json()) as T
  }

  async spider(url: string): Promise<SpiderResult> {
    const startTime = Date.now()
    const maxWaitMs = this.config.scanTimeout ?? 300000
    const startResult = await this.zapRequest<{ scan: string }>('/JSON/spider/action/scan/', {
      url,
    })

    const scanId = startResult.scan

    let progress = 0
    while (progress < 100) {
      if (Date.now() - startTime > maxWaitMs) {
        throw new Error(`ZAP spider scan timed out after ${maxWaitMs}ms (progress: ${progress}%)`)
      }
      const statusResult = await this.zapRequest<{ status: string }>(
        '/JSON/spider/view/status/',
        { scanId },
      )
      progress = parseInt(statusResult.status, 10)
      if (isNaN(progress)) {
        throw new Error(`ZAP spider returned unexpected status: ${statusResult.status}`)
      }
      if (progress < 100) {
        const delay = this.pollDelayMs >= 0 ? this.pollDelayMs : 1000
        await new Promise((resolve) => setTimeout(resolve, delay))
      }
    }

    const results = await this.zapRequest<{ results: string[] }>('/JSON/spider/view/results/', {
      scanId,
    })

    return {
      urlsFound: results.results.length,
      duration: Date.now() - startTime,
    }
  }

  async ajaxSpider(url: string): Promise<SpiderResult> {
    const startTime = Date.now()
    const maxWaitMs = this.config.scanTimeout ?? 300000
    await this.zapRequest('/JSON/ajaxSpider/action/scan/', { url })

    let status = 'running'
    while (status === 'running') {
      if (Date.now() - startTime > maxWaitMs) {
        throw new Error(`ZAP ajax spider scan timed out after ${maxWaitMs}ms`)
      }
      const statusResult = await this.zapRequest<{ status: string }>(
        '/JSON/ajaxSpider/view/status/',
      )
      status = statusResult.status
      if (status === 'running') {
        const delay = this.pollDelayMs >= 0 ? this.pollDelayMs : 2000
        await new Promise((resolve) => setTimeout(resolve, delay))
      }
    }

    const results = await this.zapRequest<{ results: string[] }>(
      '/JSON/ajaxSpider/view/results/',
    )

    return {
      urlsFound: results.results?.length ?? 0,
      duration: Date.now() - startTime,
    }
  }

  async activeScan(url: string): Promise<ScanResult> {
    const startTime = Date.now()
    const maxWaitMs = this.config.scanTimeout ?? 300000
    const startResult = await this.zapRequest<{ scan: string }>('/JSON/ascan/action/scan/', {
      url,
    })

    const scanId = startResult.scan

    let progress = 0
    while (progress < 100) {
      if (Date.now() - startTime > maxWaitMs) {
        throw new Error(`ZAP active scan timed out after ${maxWaitMs}ms (progress: ${progress}%)`)
      }
      const statusResult = await this.zapRequest<{ status: string }>(
        '/JSON/ascan/view/status/',
        { scanId },
      )
      progress = parseInt(statusResult.status, 10)
      if (isNaN(progress)) {
        throw new Error(`ZAP active scan returned unexpected status: ${statusResult.status}`)
      }
      if (progress < 100) {
        const delay = this.pollDelayMs >= 0 ? this.pollDelayMs : 2000
        await new Promise((resolve) => setTimeout(resolve, delay))
      }
    }

    await this.refreshAlerts()

    return {
      alertCount: this._alerts.length,
      duration: Date.now() - startTime,
      progress: 100,
    }
  }

  async passiveScan(url: string): Promise<ScanResult> {
    const startTime = Date.now()
    const maxWaitMs = this.config.scanTimeout ?? 300000
    // Passive scan happens automatically when spidering/browsing
    // We just need to wait for the passive scanner to finish
    let recordsRemaining = 1
    while (recordsRemaining > 0) {
      if (Date.now() - startTime > maxWaitMs) {
        throw new Error(`ZAP passive scan timed out after ${maxWaitMs}ms (records remaining: ${recordsRemaining})`)
      }
      const result = await this.zapRequest<{ recordsToScan: string }>(
        '/JSON/pscan/view/recordsToScan/',
      )
      recordsRemaining = parseInt(result.recordsToScan, 10)
      if (isNaN(recordsRemaining)) {
        throw new Error(`ZAP passive scan returned unexpected recordsToScan: ${result.recordsToScan}`)
      }
      if (recordsRemaining > 0) {
        const delay = this.pollDelayMs >= 0 ? this.pollDelayMs : 1000
        await new Promise((resolve) => setTimeout(resolve, delay))
      }
    }

    await this.refreshAlerts()

    return {
      alertCount: this._alerts.length,
      duration: Date.now() - startTime,
      progress: 100,
    }
  }

  get alerts(): SecurityAlert[] {
    return this._alerts
  }

  get alertCount(): number {
    return this._alerts.length
  }

  getAlertsByRisk(risk: RiskLevel): SecurityAlert[] {
    return this._alerts.filter((alert) => alert.risk === risk)
  }

  getAlertsByConfidence(confidence: ConfidenceLevel): SecurityAlert[] {
    return this._alerts.filter((alert) => alert.confidence === confidence)
  }

  getAlertsByType(alertType: string): SecurityAlert[] {
    return this._alerts.filter((alert) => alert.name === alertType)
  }

  async checkSecurityHeaders(url: string): Promise<HeaderCheckResult> {
    const expectedHeaders = [
      'Content-Security-Policy',
      'X-Content-Type-Options',
      'X-Frame-Options',
      'Strict-Transport-Security',
      'X-XSS-Protection',
      'Referrer-Policy',
      'Permissions-Policy',
    ]

    const response = await fetch(url)
    const headers: Record<string, string> = {}
    const missing: string[] = []
    const issues: string[] = []

    for (const header of expectedHeaders) {
      const value = response.headers.get(header)
      if (value !== null) {
        headers[header] = value
      } else {
        missing.push(header)
        issues.push(`Missing security header: ${header}`)
      }
    }

    // Also capture any other response headers
    response.headers.forEach((value, key) => {
      if (!headers[key]) {
        headers[key] = value
      }
    })

    return { headers, missing, issues }
  }

  async checkSslCertificate(url: string): Promise<SslCheckResult> {
    try {
      const response = await fetch(url)
      const isHttps = new URL(url).protocol === 'https:'

      if (!isHttps) {
        return {
          valid: false,
          expiresAt: new Date(0),
          issuer: 'N/A',
          issues: ['URL does not use HTTPS'],
        }
      }

      return {
        valid: response.ok,
        expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000), // Placeholder
        issuer: 'Unknown', // Cannot determine from fetch API
        issues: [],
      }
    } catch (error) {
      return {
        valid: false,
        expiresAt: new Date(0),
        issuer: 'Unknown',
        issues: [error instanceof Error ? error.message : 'Unknown SSL error'],
      }
    }
  }

  async generateHtmlReport(outputPath: string): Promise<void> {
    const report = await this.zapRequest<ArrayBuffer>('/OTHER/core/other/htmlreport/')
    const reportHtml =
      report instanceof ArrayBuffer
        ? new TextDecoder().decode(report)
        : String(report)
    await Bun.write(outputPath, reportHtml)
  }

  async generateJsonReport(outputPath: string): Promise<void> {
    const report = await this.zapRequest<unknown>('/OTHER/core/other/jsonreport/')
    await Bun.write(outputPath, JSON.stringify(report, null, 2))
  }

  async newSession(): Promise<void> {
    await this.zapRequest('/JSON/core/action/newSession/')
    this._alerts = []
  }

  async dispose(): Promise<void> {
    // ZAP adapter doesn't hold persistent connections
  }

  private async refreshAlerts(): Promise<void> {
    interface ZapAlert {
      name: string
      risk: string
      confidence: string
      description: string
      url: string
      solution: string
      reference: string
      cweid: string
      wascid: string
    }

    const result = await this.zapRequest<{ alerts: ZapAlert[] }>('/JSON/core/view/alerts/')

    this._alerts = result.alerts.map((alert) => ({
      name: alert.name,
      risk: alert.risk as RiskLevel,
      confidence: alert.confidence as SecurityAlert['confidence'],
      description: alert.description,
      url: alert.url,
      solution: alert.solution,
      reference: alert.reference ?? '',
      cweid: alert.cweid,
      wascid: alert.wascid ?? '',
    }))
  }
}
