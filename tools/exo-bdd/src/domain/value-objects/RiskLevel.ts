export type RiskLevel = 'High' | 'Medium' | 'Low' | 'Informational'

export const RiskLevel = {
  High: 'High' as const,
  Medium: 'Medium' as const,
  Low: 'Low' as const,
  Informational: 'Informational' as const,

  compare(a: RiskLevel, b: RiskLevel): number {
    const order: Record<RiskLevel, number> = { High: 3, Medium: 2, Low: 1, Informational: 0 }
    return order[a] - order[b]
  },

  isAtLeast(level: RiskLevel, threshold: RiskLevel): boolean {
    return this.compare(level, threshold) >= 0
  },
}
