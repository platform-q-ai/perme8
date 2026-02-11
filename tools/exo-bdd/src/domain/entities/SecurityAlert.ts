import type { RiskLevel } from '../value-objects/RiskLevel.ts'

export type ConfidenceLevel = 'High' | 'Medium' | 'Low' | 'Confirmed'

export interface SecurityAlert {
  readonly name: string
  readonly risk: RiskLevel
  readonly confidence: ConfidenceLevel
  readonly description: string
  readonly url: string
  readonly solution: string
  readonly reference: string
  readonly cweid: string
  readonly wascid: string
}

export interface ScanResult {
  readonly alertCount: number
  readonly duration: number
  readonly progress: number
}

export interface SpiderResult {
  readonly urlsFound: number
  readonly duration: number
}

export interface HeaderCheckResult {
  readonly headers: Record<string, string>
  readonly missing: string[]
  readonly issues: string[]
}

export interface SslCheckResult {
  readonly valid: boolean
  readonly expiresAt: Date
  readonly issuer: string
  readonly issues: string[]
}
