# Implementation Plan: Exo BDD Framework

Following Clean Architecture principles, this plan organizes the framework into distinct layers with clear dependency rules.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Interface Layer                          │
│  (Step Definitions, Hooks, World Setup, CLI Entry Points)   │
├─────────────────────────────────────────────────────────────┤
│                   Application Layer                         │
│  (Use Cases, Ports/Interfaces, Configuration Loading)       │
├─────────────────────────────────────────────────────────────┤
│                     Domain Layer                            │
│  (Entities, Value Objects, Core Types, Business Rules)      │
├─────────────────────────────────────────────────────────────┤
│                  Infrastructure Layer                       │
│  (Adapter Implementations, External Library Wrappers)       │
└─────────────────────────────────────────────────────────────┘
```

## Project Structure

```
exo-bdd/
├── src/
│   ├── domain/                      # Core business logic (no dependencies)
│   │   ├── entities/
│   │   │   ├── Variable.ts
│   │   │   ├── HttpRequest.ts
│   │   │   ├── HttpResponse.ts
│   │   │   ├── CommandResult.ts
│   │   │   ├── GraphNode.ts
│   │   │   ├── SecurityAlert.ts
│   │   │   └── index.ts
│   │   ├── value-objects/
│   │   │   ├── RiskLevel.ts
│   │   │   ├── NodeType.ts
│   │   │   ├── JsonPath.ts
│   │   │   └── index.ts
│   │   ├── errors/
│   │   │   ├── DomainError.ts
│   │   │   ├── VariableNotFoundError.ts
│   │   │   ├── AdapterNotConfiguredError.ts
│   │   │   └── index.ts
│   │   └── index.ts
│   │
│   ├── application/                 # Use cases and port definitions
│   │   ├── ports/                   # Interfaces (adapters implement these)
│   │   │   ├── HttpPort.ts
│   │   │   ├── BrowserPort.ts
│   │   │   ├── CliPort.ts
│   │   │   ├── GraphPort.ts
│   │   │   ├── SecurityPort.ts
│   │   │   └── index.ts
│   │   ├── services/
│   │   │   ├── VariableService.ts
│   │   │   ├── InterpolationService.ts
│   │   │   └── index.ts
│   │   ├── config/
│   │   │   ├── ConfigSchema.ts
│   │   │   ├── ConfigLoader.ts
│   │   │   └── index.ts
│   │   └── index.ts
│   │
│   ├── infrastructure/              # External implementations
│   │   ├── adapters/
│   │   │   ├── http/
│   │   │   │   ├── PlaywrightHttpAdapter.ts
│   │   │   │   └── index.ts
│   │   │   ├── browser/
│   │   │   │   ├── PlaywrightBrowserAdapter.ts
│   │   │   │   └── index.ts
│   │   │   ├── cli/
│   │   │   │   ├── BunCliAdapter.ts
│   │   │   │   └── index.ts
│   │   │   ├── graph/
│   │   │   │   ├── Neo4jGraphAdapter.ts
│   │   │   │   └── index.ts
│   │   │   ├── security/
│   │   │   │   ├── ZapSecurityAdapter.ts
│   │   │   │   └── index.ts
│   │   │   └── index.ts
│   │   ├── factories/
│   │   │   ├── AdapterFactory.ts
│   │   │   └── index.ts
│   │   └── index.ts
│   │
│   ├── interface/                   # Cucumber integration layer
│   │   ├── world/
│   │   │   ├── TestWorld.ts
│   │   │   └── index.ts
│   │   ├── hooks/
│   │   │   ├── lifecycle.ts
│   │   │   ├── tagged.ts
│   │   │   └── index.ts
│   │   ├── steps/
│   │   │   ├── http/
│   │   │   │   ├── request-building.steps.ts
│   │   │   │   ├── http-methods.steps.ts
│   │   │   │   ├── response-assertions.steps.ts
│   │   │   │   └── index.ts
│   │   │   ├── browser/
│   │   │   │   ├── navigation.steps.ts
│   │   │   │   ├── interactions.steps.ts
│   │   │   │   ├── assertions.steps.ts
│   │   │   │   └── index.ts
│   │   │   ├── cli/
│   │   │   │   ├── environment.steps.ts
│   │   │   │   ├── execution.steps.ts
│   │   │   │   ├── assertions.steps.ts
│   │   │   │   └── index.ts
│   │   │   ├── graph/
│   │   │   │   ├── selection.steps.ts
│   │   │   │   ├── dependency-assertions.steps.ts
│   │   │   │   ├── query.steps.ts
│   │   │   │   └── index.ts
│   │   │   ├── security/
│   │   │   │   ├── scanning.steps.ts
│   │   │   │   ├── assertions.steps.ts
│   │   │   │   └── index.ts
│   │   │   ├── variables.steps.ts
│   │   │   └── index.ts
│   │   └── index.ts
│   │
│   └── index.ts                     # Public API exports
│
├── package.json
├── tsconfig.json
└── README.md
```

---

## Phase 1: Domain Layer

**Goal**: Define core entities, value objects, and domain errors with zero external dependencies.

### 1.1 Value Objects

```typescript
// src/domain/value-objects/RiskLevel.ts
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
  }
}
```

```typescript
// src/domain/value-objects/NodeType.ts
export type NodeType = 'class' | 'interface' | 'function' | 'file' | 'module'
```

```typescript
// src/domain/value-objects/JsonPath.ts
export class JsonPath {
  constructor(public readonly expression: string) {
    if (!expression.startsWith('$')) {
      throw new Error('JSONPath must start with $')
    }
  }
  
  toString(): string {
    return this.expression
  }
}
```

### 1.2 Entities

```typescript
// src/domain/entities/HttpResponse.ts
export interface HttpResponse {
  readonly status: number
  readonly statusText: string
  readonly headers: Readonly<Record<string, string>>
  readonly body: unknown
  readonly text: string
  readonly responseTime: number
}

// src/domain/entities/CommandResult.ts
export interface CommandResult {
  readonly stdout: string
  readonly stderr: string
  readonly exitCode: number
  readonly duration: number
}

// src/domain/entities/GraphNode.ts
export interface GraphNode {
  readonly name: string
  readonly fqn: string
  readonly type: NodeType
  readonly layer?: string
  readonly file?: string
}

// src/domain/entities/SecurityAlert.ts
export interface SecurityAlert {
  readonly name: string
  readonly risk: RiskLevel
  readonly confidence: ConfidenceLevel
  readonly description: string
  readonly url: string
  readonly solution: string
  readonly cweid: string
}
```

### 1.3 Domain Errors

```typescript
// src/domain/errors/DomainError.ts
export abstract class DomainError extends Error {
  abstract readonly code: string
}

// src/domain/errors/VariableNotFoundError.ts
export class VariableNotFoundError extends DomainError {
  readonly code = 'VARIABLE_NOT_FOUND'
  constructor(name: string) {
    super(`Variable "${name}" is not defined`)
  }
}

// src/domain/errors/AdapterNotConfiguredError.ts
export class AdapterNotConfiguredError extends DomainError {
  readonly code = 'ADAPTER_NOT_CONFIGURED'
  constructor(adapter: string) {
    super(`Adapter "${adapter}" is not configured`)
  }
}
```

---

## Phase 2: Application Layer

**Goal**: Define ports (interfaces) and application services. No framework dependencies.

### 2.1 Port Interfaces

```typescript
// src/application/ports/HttpPort.ts
import type { HttpResponse } from '../../domain/entities'

export interface HttpPort {
  // Request building (chainable)
  setHeader(name: string, value: string): this
  setHeaders(headers: Record<string, string>): this
  setQueryParam(name: string, value: string): this
  setQueryParams(params: Record<string, string>): this
  setBearerToken(token: string): this
  setBasicAuth(username: string, password: string): this
  
  // HTTP methods
  get(path: string): Promise<void>
  post(path: string, body?: unknown): Promise<void>
  put(path: string, body?: unknown): Promise<void>
  patch(path: string, body?: unknown): Promise<void>
  delete(path: string): Promise<void>
  
  // Response accessors
  readonly response: HttpResponse
  readonly status: number
  readonly body: unknown
  
  // Utilities
  getBodyPath(jsonPath: string): unknown
  
  // Lifecycle
  dispose(): Promise<void>
}
```

```typescript
// src/application/ports/BrowserPort.ts
export interface BrowserPort {
  // Navigation
  goto(path: string): Promise<void>
  reload(): Promise<void>
  goBack(): Promise<void>
  
  // Interactions
  click(selector: string): Promise<void>
  fill(selector: string, value: string): Promise<void>
  selectOption(selector: string, value: string): Promise<void>
  check(selector: string): Promise<void>
  
  // Waiting
  waitForSelector(selector: string, options?: WaitOptions): Promise<void>
  waitForNavigation(): Promise<void>
  
  // Information
  url(): string
  title(): Promise<string>
  textContent(selector: string): Promise<string | null>
  isVisible(selector: string): Promise<boolean>
  
  // Screenshots
  screenshot(): Promise<Buffer>
  
  // Lifecycle
  clearContext(): Promise<void>
  dispose(): Promise<void>
}
```

```typescript
// src/application/ports/CliPort.ts
import type { CommandResult } from '../../domain/entities'

export interface CliPort {
  // Environment
  setEnv(name: string, value: string): this
  setWorkingDir(dir: string): this
  
  // Execution
  run(command: string): Promise<CommandResult>
  runWithStdin(command: string, stdin: string): Promise<CommandResult>
  
  // Result accessors
  readonly result: CommandResult
  readonly stdout: string
  readonly stderr: string
  readonly exitCode: number
  
  // Lifecycle
  dispose(): Promise<void>
}
```

```typescript
// src/application/ports/GraphPort.ts
import type { GraphNode, Dependency, Cycle } from '../../domain/entities'

export interface GraphPort {
  // Connection
  connect(): Promise<void>
  disconnect(): Promise<void>
  
  // Queries
  query<T>(cypher: string, params?: Record<string, unknown>): Promise<T[]>
  
  // High-level helpers
  getNodesInLayer(layer: string, type?: NodeType): Promise<GraphNode[]>
  getLayerDependencies(from: string, to: string): Promise<Dependency[]>
  findCircularDependencies(): Promise<Cycle[]>
  getClassesImplementing(interfaceName: string): Promise<GraphNode[]>
  
  // Lifecycle
  dispose(): Promise<void>
}
```

```typescript
// src/application/ports/SecurityPort.ts
import type { SecurityAlert, ScanResult } from '../../domain/entities'

export interface SecurityPort {
  // Scanning
  spider(url: string): Promise<SpiderResult>
  activeScan(url: string): Promise<ScanResult>
  passiveScan(url: string): Promise<ScanResult>
  
  // Alerts
  readonly alerts: SecurityAlert[]
  getAlertsByRisk(risk: RiskLevel): SecurityAlert[]
  
  // Header/SSL checks
  checkSecurityHeaders(url: string): Promise<HeaderCheckResult>
  checkSslCertificate(url: string): Promise<SslCheckResult>
  
  // Reporting
  generateHtmlReport(outputPath: string): Promise<void>
  
  // Lifecycle
  newSession(): Promise<void>
  dispose(): Promise<void>
}
```

### 2.2 Application Services

```typescript
// src/application/services/VariableService.ts
import { VariableNotFoundError } from '../../domain/errors'

export class VariableService {
  private variables = new Map<string, unknown>()
  
  set(name: string, value: unknown): void {
    this.variables.set(name, value)
  }
  
  get<T>(name: string): T {
    if (!this.variables.has(name)) {
      throw new VariableNotFoundError(name)
    }
    return this.variables.get(name) as T
  }
  
  has(name: string): boolean {
    return this.variables.has(name)
  }
  
  clear(): void {
    this.variables.clear()
  }
}
```

```typescript
// src/application/services/InterpolationService.ts
import { VariableService } from './VariableService'
import { v4 as uuidv4 } from 'uuid'

export class InterpolationService {
  constructor(private variables: VariableService) {}
  
  interpolate(text: string): string {
    return text.replace(/\$\{(\w+)\}/g, (_, name) => {
      // Handle built-in variables
      switch (name) {
        case 'timestamp': return String(Math.floor(Date.now() / 1000))
        case 'timestamp_ms': return String(Date.now())
        case 'iso_date': return new Date().toISOString()
        case 'uuid': return uuidv4()
        case 'random_int': return String(Math.floor(Math.random() * 1000000))
        case 'random_string': return this.randomString(8)
        case 'random_email': return `test_${this.randomString(6)}@example.com`
        default: return String(this.variables.get(name))
      }
    })
  }
  
  private randomString(length: number): string {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    return Array.from({ length }, () => chars[Math.floor(Math.random() * chars.length)]).join('')
  }
}
```

### 2.3 Configuration

```typescript
// src/application/config/ConfigSchema.ts
export interface ExoBddConfig {
  adapters: {
    http?: HttpAdapterConfig
    browser?: BrowserAdapterConfig
    cli?: CliAdapterConfig
    graph?: GraphAdapterConfig
    security?: SecurityAdapterConfig
  }
}

export interface HttpAdapterConfig {
  baseURL: string
  timeout?: number
  headers?: Record<string, string>
  auth?: { type: 'bearer' | 'basic'; token?: string; username?: string; password?: string }
}

// ... other config interfaces as per spec
```

```typescript
// src/application/config/ConfigLoader.ts
import type { ExoBddConfig } from './ConfigSchema'
import { pathToFileURL } from 'url'
import { resolve } from 'path'

export async function loadConfig(configPath?: string): Promise<ExoBddConfig> {
  const path = configPath ?? resolve(process.cwd(), 'exo-bdd.config.ts')
  const module = await import(pathToFileURL(path).href)
  return module.default
}

export function defineConfig(config: ExoBddConfig): ExoBddConfig {
  return config
}
```

---

## Phase 3: Infrastructure Layer

**Goal**: Implement adapters using external libraries (Playwright, Neo4j, etc.)

### 3.1 HTTP Adapter (Playwright)

```typescript
// src/infrastructure/adapters/http/PlaywrightHttpAdapter.ts
import { request, APIRequestContext, APIResponse } from '@playwright/test'
import type { HttpPort } from '../../../application/ports'
import type { HttpAdapterConfig } from '../../../application/config'
import type { HttpResponse } from '../../../domain/entities'
import JSONPath from 'jsonpath'

export class PlaywrightHttpAdapter implements HttpPort {
  private context!: APIRequestContext
  private pendingHeaders: Record<string, string> = {}
  private pendingQueryParams: Record<string, string> = {}
  private _response!: HttpResponse
  private rawResponse!: APIResponse
  
  constructor(private readonly config: HttpAdapterConfig) {}
  
  async initialize(): Promise<void> {
    this.context = await request.newContext({
      baseURL: this.config.baseURL,
      timeout: this.config.timeout ?? 30000,
      extraHTTPHeaders: this.config.headers
    })
  }
  
  setHeader(name: string, value: string): this {
    this.pendingHeaders[name] = value
    return this
  }
  
  setBearerToken(token: string): this {
    return this.setHeader('Authorization', `Bearer ${token}`)
  }
  
  async get(path: string): Promise<void> {
    await this.request('GET', path)
  }
  
  async post(path: string, body?: unknown): Promise<void> {
    await this.request('POST', path, body)
  }
  
  private async request(method: string, path: string, body?: unknown): Promise<void> {
    const startTime = Date.now()
    
    const url = this.buildUrl(path)
    this.rawResponse = await this.context.fetch(url, {
      method,
      headers: this.pendingHeaders,
      data: body
    })
    
    const responseBody = await this.rawResponse.text()
    
    this._response = {
      status: this.rawResponse.status(),
      statusText: this.rawResponse.statusText(),
      headers: Object.fromEntries(this.rawResponse.headersArray().map(h => [h.name, h.value])),
      body: this.parseBody(responseBody),
      text: responseBody,
      responseTime: Date.now() - startTime
    }
    
    this.resetPending()
  }
  
  get response(): HttpResponse { return this._response }
  get status(): number { return this._response.status }
  get body(): unknown { return this._response.body }
  
  getBodyPath(jsonPath: string): unknown {
    return JSONPath.query(this._response.body, jsonPath)[0]
  }
  
  async dispose(): Promise<void> {
    await this.context.dispose()
  }
  
  private buildUrl(path: string): string {
    const url = new URL(path, this.config.baseURL)
    Object.entries(this.pendingQueryParams).forEach(([k, v]) => url.searchParams.set(k, v))
    return url.toString()
  }
  
  private parseBody(text: string): unknown {
    try { return JSON.parse(text) } catch { return text }
  }
  
  private resetPending(): void {
    this.pendingHeaders = {}
    this.pendingQueryParams = {}
  }
}
```

### 3.2 Browser Adapter (Playwright)

```typescript
// src/infrastructure/adapters/browser/PlaywrightBrowserAdapter.ts
import { chromium, Browser, BrowserContext, Page } from '@playwright/test'
import type { BrowserPort } from '../../../application/ports'
import type { BrowserAdapterConfig } from '../../../application/config'

export class PlaywrightBrowserAdapter implements BrowserPort {
  private browser!: Browser
  private context!: BrowserContext
  private _page!: Page
  
  constructor(private readonly config: BrowserAdapterConfig) {}
  
  async initialize(): Promise<void> {
    this.browser = await chromium.launch({ headless: this.config.headless ?? true })
    this.context = await this.browser.newContext({
      viewport: this.config.viewport,
      baseURL: this.config.baseURL
    })
    this._page = await this.context.newPage()
  }
  
  get page(): Page { return this._page }
  
  async goto(path: string): Promise<void> {
    await this._page.goto(path)
  }
  
  async click(selector: string): Promise<void> {
    await this._page.click(selector)
  }
  
  async fill(selector: string, value: string): Promise<void> {
    await this._page.fill(selector, value)
  }
  
  async waitForSelector(selector: string): Promise<void> {
    await this._page.waitForSelector(selector)
  }
  
  url(): string {
    return this._page.url()
  }
  
  async screenshot(): Promise<Buffer> {
    return await this._page.screenshot()
  }
  
  async clearContext(): Promise<void> {
    await this.context.clearCookies()
    await this._page.evaluate(() => localStorage.clear())
  }
  
  async dispose(): Promise<void> {
    await this.context.close()
    await this.browser.close()
  }
}
```

### 3.3 Adapter Factory

```typescript
// src/infrastructure/factories/AdapterFactory.ts
import type { ExoBddConfig } from '../../application/config'
import type { HttpPort, BrowserPort, CliPort, GraphPort, SecurityPort } from '../../application/ports'
import { PlaywrightHttpAdapter } from '../adapters/http/PlaywrightHttpAdapter'
import { PlaywrightBrowserAdapter } from '../adapters/browser/PlaywrightBrowserAdapter'
import { BunCliAdapter } from '../adapters/cli/BunCliAdapter'
import { Neo4jGraphAdapter } from '../adapters/graph/Neo4jGraphAdapter'
import { ZapSecurityAdapter } from '../adapters/security/ZapSecurityAdapter'

export interface Adapters {
  http?: HttpPort
  browser?: BrowserPort
  cli?: CliPort
  graph?: GraphPort
  security?: SecurityPort
  dispose(): Promise<void>
}

export async function createAdapters(config: ExoBddConfig): Promise<Adapters> {
  const adapters: Partial<Adapters> = {}
  
  if (config.adapters.http) {
    const http = new PlaywrightHttpAdapter(config.adapters.http)
    await http.initialize()
    adapters.http = http
  }
  
  if (config.adapters.browser) {
    const browser = new PlaywrightBrowserAdapter(config.adapters.browser)
    await browser.initialize()
    adapters.browser = browser
  }
  
  if (config.adapters.cli) {
    adapters.cli = new BunCliAdapter(config.adapters.cli)
  }
  
  if (config.adapters.graph) {
    const graph = new Neo4jGraphAdapter(config.adapters.graph)
    await graph.connect()
    adapters.graph = graph
  }
  
  if (config.adapters.security) {
    adapters.security = new ZapSecurityAdapter(config.adapters.security)
  }
  
  return {
    ...adapters,
    async dispose() {
      await Promise.all([
        adapters.http?.dispose(),
        adapters.browser?.dispose(),
        adapters.cli?.dispose(),
        adapters.graph?.dispose(),
        adapters.security?.dispose()
      ])
    }
  } as Adapters
}
```

---

## Phase 4: Interface Layer

**Goal**: Cucumber integration - TestWorld, hooks, and step definitions.

### 4.1 TestWorld

```typescript
// src/interface/world/TestWorld.ts
import { World, IWorldOptions } from '@cucumber/cucumber'
import type { HttpPort, BrowserPort, CliPort, GraphPort, SecurityPort } from '../../application/ports'
import { VariableService } from '../../application/services/VariableService'
import { InterpolationService } from '../../application/services/InterpolationService'

export class TestWorld extends World {
  // Adapters (attached in Before hook)
  http!: HttpPort
  browser!: BrowserPort
  cli!: CliPort
  graph!: GraphPort
  security!: SecurityPort
  
  // Services
  private variableService = new VariableService()
  private interpolationService = new InterpolationService(this.variableService)
  
  constructor(options: IWorldOptions) {
    super(options)
  }
  
  setVariable(name: string, value: unknown): void {
    this.variableService.set(name, value)
  }
  
  getVariable<T>(name: string): T {
    return this.variableService.get<T>(name)
  }
  
  interpolate(text: string): string {
    return this.interpolationService.interpolate(text)
  }
  
  reset(): void {
    this.variableService.clear()
  }
}
```

### 4.2 Lifecycle Hooks

```typescript
// src/interface/hooks/lifecycle.ts
import { BeforeAll, AfterAll, Before, After, setWorldConstructor, Status } from '@cucumber/cucumber'
import { loadConfig } from '../../application/config'
import { createAdapters, Adapters } from '../../infrastructure/factories'
import { TestWorld } from '../world'

setWorldConstructor(TestWorld)

let adapters: Adapters

BeforeAll(async function () {
  const config = await loadConfig()
  adapters = await createAdapters(config)
})

Before(async function (this: TestWorld) {
  // Attach adapters
  if (adapters.http) this.http = adapters.http
  if (adapters.browser) this.browser = adapters.browser
  if (adapters.cli) this.cli = adapters.cli
  if (adapters.graph) this.graph = adapters.graph
  if (adapters.security) this.security = adapters.security
  
  // Reset scenario state
  this.reset()
})

After(async function (this: TestWorld, scenario) {
  if (scenario.result?.status === Status.FAILED && this.browser) {
    const screenshot = await this.browser.screenshot()
    this.attach(screenshot, 'image/png')
  }
  await this.browser?.clearContext()
})

AfterAll(async function () {
  await adapters?.dispose()
})
```

### 4.3 Step Definitions (HTTP Example)

```typescript
// src/interface/steps/http/request-building.steps.ts
import { Given } from '@cucumber/cucumber'
import { TestWorld } from '../../world'

Given<TestWorld>(
  'I set header {string} to {string}',
  function (name: string, value: string) {
    this.http.setHeader(name, this.interpolate(value))
  }
)

Given<TestWorld>(
  'I set bearer token to {string}',
  function (token: string) {
    this.http.setBearerToken(this.interpolate(token))
  }
)

Given<TestWorld>(
  'I set query param {string} to {string}',
  function (name: string, value: string) {
    this.http.setQueryParam(name, this.interpolate(value))
  }
)
```

```typescript
// src/interface/steps/http/http-methods.steps.ts
import { When } from '@cucumber/cucumber'
import { TestWorld } from '../../world'

When<TestWorld>('I GET {string}', async function (path: string) {
  await this.http.get(this.interpolate(path))
})

When<TestWorld>('I POST to {string}', async function (path: string) {
  await this.http.post(this.interpolate(path))
})

When<TestWorld>('I POST to {string} with body:', async function (path: string, docString: string) {
  const body = JSON.parse(this.interpolate(docString))
  await this.http.post(this.interpolate(path), body)
})

When<TestWorld>('I PUT to {string} with body:', async function (path: string, docString: string) {
  const body = JSON.parse(this.interpolate(docString))
  await this.http.put(this.interpolate(path), body)
})

When<TestWorld>('I DELETE {string}', async function (path: string) {
  await this.http.delete(this.interpolate(path))
})
```

```typescript
// src/interface/steps/http/response-assertions.steps.ts
import { Then } from '@cucumber/cucumber'
import { expect } from '@playwright/test'
import { TestWorld } from '../../world'

Then<TestWorld>(
  'the response status should be {int}',
  function (expectedStatus: number) {
    expect(this.http.status).toBe(expectedStatus)
  }
)

Then<TestWorld>(
  'the response body path {string} should equal {string}',
  function (jsonPath: string, expectedValue: string) {
    const actual = this.http.getBodyPath(jsonPath)
    expect(actual).toBe(this.interpolate(expectedValue))
  }
)

Then<TestWorld>(
  'the response body path {string} should exist',
  function (jsonPath: string) {
    const value = this.http.getBodyPath(jsonPath)
    expect(value).toBeDefined()
  }
)

Then<TestWorld>(
  'I store response body path {string} as {string}',
  function (jsonPath: string, variableName: string) {
    const value = this.http.getBodyPath(jsonPath)
    this.setVariable(variableName, value)
  }
)
```

---

## Phase 5: Public API

```typescript
// src/index.ts
// Configuration
export { defineConfig, loadConfig } from './application/config'
export type { ExoBddConfig, HttpAdapterConfig, BrowserAdapterConfig } from './application/config'

// Ports (for custom adapter implementations)
export type { HttpPort, BrowserPort, CliPort, GraphPort, SecurityPort } from './application/ports'

// Factories
export { createAdapters } from './infrastructure/factories'
export type { Adapters } from './infrastructure/factories'

// World
export { TestWorld } from './interface/world'

// Domain types
export type { HttpResponse, CommandResult, GraphNode, SecurityAlert } from './domain/entities'
export { RiskLevel, NodeType } from './domain/value-objects'

// Errors
export { DomainError, VariableNotFoundError, AdapterNotConfiguredError } from './domain/errors'
```

---

## Implementation Order

| Phase | Tasks | Est. Time |
|-------|-------|-----------|
| **1** | Domain: Value objects, entities, errors | 2 days |
| **2** | Application: Ports, services, config | 3 days |
| **3a** | Infrastructure: HTTP adapter | 2 days |
| **3b** | Infrastructure: Browser adapter | 2 days |
| **3c** | Infrastructure: CLI adapter | 1 day |
| **3d** | Infrastructure: Graph adapter | 2 days |
| **3e** | Infrastructure: Security adapter | 2 days |
| **3f** | Infrastructure: Adapter factory | 1 day |
| **4a** | Interface: TestWorld + Hooks | 1 day |
| **4b** | Interface: HTTP steps (~20 steps) | 2 days |
| **4c** | Interface: Browser steps (~25 steps) | 2 days |
| **4d** | Interface: CLI steps (~15 steps) | 1 day |
| **4e** | Interface: Graph steps (~15 steps) | 2 days |
| **4f** | Interface: Security steps (~15 steps) | 2 days |
| **5** | Public API exports + docs | 1 day |
| **6** | Integration tests + polish | 3 days |

**Total: ~29 days**

---

## Dependency Rule Summary

```
Domain ← Application ← Infrastructure
                    ← Interface

Domain:        No imports from other layers
Application:   Imports only Domain
Infrastructure: Imports Application + Domain
Interface:     Imports Application + Domain + Infrastructure (factories only)
```

This ensures the core business logic (Domain) remains pure and testable, while external concerns (Playwright, Neo4j, ZAP) are isolated in Infrastructure.
