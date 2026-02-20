// Configuration
export { defineConfig, loadConfig } from './application/config/index.ts'
export type {
  ExoBddConfig,
  ServerConfig,
  HttpAdapterConfig,
  BrowserAdapterConfig,
  CliAdapterConfig,
  GraphAdapterConfig,
  SecurityAdapterConfig,
  ReportConfig,
} from './application/config/index.ts'

// Ports (for custom adapter implementations)
export type { HttpPort } from './application/ports/index.ts'
export type { BrowserPort, WaitOptions } from './application/ports/index.ts'
export type { CliPort } from './application/ports/index.ts'
export type { GraphPort } from './application/ports/index.ts'
export type { SecurityPort } from './application/ports/index.ts'

// Spec-compatible adapter type aliases
// The spec refers to these as "Adapters" rather than "Ports"
import type { HttpPort } from './application/ports/index.ts'
import type { BrowserPort } from './application/ports/index.ts'
import type { CliPort } from './application/ports/index.ts'
import type { GraphPort } from './application/ports/index.ts'
import type { SecurityPort } from './application/ports/index.ts'
export type HttpAdapter = HttpPort
export type BrowserAdapter = BrowserPort
export type CliAdapter = CliPort
export type GraphAdapter = GraphPort
export type SecurityAdapter = SecurityPort

// Adapter factory
export { createAdapters } from './infrastructure/factories/index.ts'

// Adapters interface (from application layer per Clean Architecture)
export type { Adapters } from './application/ports/index.ts'

// World
export { TestWorld } from './interface/world/index.ts'

// Domain types
export type {
  HttpResponse,
  HttpRequest,
  CommandResult,
  GraphNode,
  DependencyType,
  Dependency,
  Cycle,
  LayerInfo,
  QueryResult,
  ScreenshotOptions,
  SecurityAlert,
  ConfidenceLevel,
  ScanResult,
  SpiderResult,
  HeaderCheckResult,
  SslCheckResult,
  Variable,
} from './domain/entities/index.ts'

// Spec-compatible type aliases for domain entities
import type { GraphNode, SecurityAlert } from './domain/entities/index.ts'
export type Node = GraphNode
export type Alert = SecurityAlert

export { RiskLevel } from './domain/value-objects/index.ts'
export type { NodeType } from './domain/value-objects/index.ts'
export { JsonPath } from './domain/value-objects/index.ts'

// Errors
export { DomainError, VariableNotFoundError, AdapterNotConfiguredError } from './domain/errors/index.ts'

// Services (for advanced usage)
export { VariableService } from './application/services/index.ts'
export { InterpolationService } from './application/services/index.ts'
