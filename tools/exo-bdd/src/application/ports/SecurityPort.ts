import type {
  SecurityAlert,
  ConfidenceLevel,
  ScanResult,
  SpiderResult,
  HeaderCheckResult,
  SslCheckResult,
} from '../../domain/entities/index.ts'
import type { RiskLevel } from '../../domain/value-objects/index.ts'
import type { SecurityAdapterConfig } from '../config/ConfigSchema.ts'

export interface SecurityPort {
  // Configuration
  readonly config: SecurityAdapterConfig

  // Scanning
  spider(url: string): Promise<SpiderResult>
  activeScan(url: string): Promise<ScanResult>
  passiveScan(url: string): Promise<ScanResult>
  ajaxSpider(url: string): Promise<SpiderResult>

  // Result accessors
  readonly alerts: SecurityAlert[]
  readonly alertCount: number

  // Alert filtering
  getAlertsByRisk(risk: RiskLevel): SecurityAlert[]
  getAlertsByConfidence(confidence: ConfidenceLevel): SecurityAlert[]
  getAlertsByType(alertType: string): SecurityAlert[]

  // Specific checks
  checkSecurityHeaders(url: string): Promise<HeaderCheckResult>
  checkSslCertificate(url: string): Promise<SslCheckResult>

  // Session management
  newSession(): Promise<void>

  // Reporting
  generateHtmlReport(outputPath: string): Promise<void>
  generateJsonReport(outputPath: string): Promise<void>

  // Lifecycle
  dispose(): Promise<void>
}
