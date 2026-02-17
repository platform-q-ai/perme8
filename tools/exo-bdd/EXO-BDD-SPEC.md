# Exo BDD Specification

**Version:** 0.2.0  
**Status:** Draft  

A Cucumber.js-based BDD framework for external/black-box testing, optimized for LLM-generated step definitions.

---

## Table of Contents

1. [Philosophy](#1-philosophy)
2. [Project Setup](#2-project-setup)
3. [Configuration](#3-configuration)
4. [TestWorld Class](#4-testworld-class)
5. [Hooks & Lifecycle](#5-hooks--lifecycle)
6. [Adapters](#6-adapters)
   - [6.1 HTTP Adapter](#61-http-adapter)
   - [6.2 Browser Adapter](#62-browser-adapter)
   - [6.3 CLI Adapter](#63-cli-adapter)
   - [6.4 Graph Database Adapter](#64-graph-database-adapter)
   - [6.5 Security Adapter](#65-security-adapter)
7. [Variables & State](#7-variables--state)
8. [Writing Custom Steps](#8-writing-custom-steps)
9. [Running Tests](#9-running-tests)
10. [Appendix: Core Step Reference](#10-appendix-core-step-reference)

---

## 1. Philosophy

### 1.1 Guiding Principles

1. **External-Only Testing**: All tests interact with systems from the outside—no internal code access, mocking, or instrumentation required.

2. **Cucumber-Native**: Use `@cucumber/cucumber` directly. No custom BDD engine, no wrapper CLI. Leverage the mature ecosystem.

3. **LLM-Optimized**: Technology choices prioritize tools with extensive documentation and LLM training data. Step definitions use patterns that LLMs generate accurately.

4. **Adapter Pattern**: Each external system type (HTTP, Browser, CLI, Graph, Security) has a dedicated adapter with a consistent interface.

5. **TypeScript-First**: Strong typing helps LLMs write correct code and enables better IDE support.

### 1.2 What This Framework Provides

- **Adapter implementations** for HTTP, Browser, CLI, Graph Database, and Security testing
- **TestWorld class** that wires adapters together with typed interfaces
- **Core step definitions** (~75 pre-built steps) that use the adapters
- **Configuration loader** for typed `exo-bdd.config.ts` files

### 1.3 What This Framework Does NOT Provide

- A replacement for Cucumber.js
- A custom CLI (use `cucumber-js` directly)
- Internal/unit testing capabilities
- Graph database population tools (out of scope)

---

## 2. Project Setup

### 2.1 Project Structure

```
my-tests/
├── cucumber.js               # Cucumber configuration (standard)
├── exo-bdd.config.ts      # Adapter configuration
├── features/
│   ├── api/
│   │   └── users.feature
│   ├── web/
│   │   └── login.feature
│   └── architecture/
│       └── clean-arch.feature
├── support/
│   ├── world.ts              # TestWorld with adapters
│   └── hooks.ts              # Lifecycle hooks
├── steps/
│   ├── index.ts              # Re-exports core steps
│   └── custom/               # LLM-generated custom steps
│       └── my-steps.ts
├── tsconfig.json
└── package.json
```

### 2.2 Dependencies

```json
{
  "devDependencies": {
    "@cucumber/cucumber": "^10.0.0",
    "exo-bdd": "^0.1.0",
    "@playwright/test": "^1.40.0",
    "neo4j-driver": "^5.0.0",
    "typescript": "^5.0.0"
  }
}
```

### 2.3 Cucumber Configuration

```javascript
// cucumber.js
module.exports = {
  default: {
    requireModule: ['ts-node/register'],
    require: ['support/**/*.ts', 'steps/**/*.ts'],
    paths: ['features/**/*.feature'],
    format: ['progress-bar', 'html:reports/cucumber.html'],
    formatOptions: { snippetInterface: 'async-await' }
  }
}
```

### 2.4 TypeScript Configuration

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "commonjs",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "outDir": "./dist",
    "rootDir": "./"
  },
  "include": ["support/**/*", "steps/**/*", "exo-bdd.config.ts"]
}
```

---

## 3. Configuration

### 3.1 Configuration File

```typescript
// exo-bdd.config.ts
import { defineConfig } from 'exo-bdd'

export default defineConfig({
  adapters: {
    http: {
      baseURL: process.env.API_URL ?? 'http://localhost:3000',
      timeout: 30000,
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json'
      }
    },
    
    browser: {
      baseURL: process.env.APP_URL ?? 'http://localhost:3000',
      headless: process.env.CI === 'true',
      viewport: { width: 1280, height: 720 },
      screenshot: 'only-on-failure'
    },
    
    cli: {
      workingDir: process.cwd(),
      shell: '/bin/bash',
      timeout: 60000,
      env: {
        NODE_ENV: 'test'
      }
    },
    
    graph: {
      uri: process.env.NEO4J_URI ?? 'bolt://localhost:7687',
      username: process.env.NEO4J_USER ?? 'neo4j',
      password: process.env.NEO4J_PASSWORD ?? 'password',
      database: 'codebase'
    },
    
    security: {
      zapUrl: process.env.ZAP_URL ?? 'http://localhost:8080',
      zapApiKey: process.env.ZAP_API_KEY
    }
  }
})
```

### 3.2 Configuration Types

```typescript
interface ExoBddConfig {
  adapters: {
    http?: HttpAdapterConfig
    browser?: BrowserAdapterConfig
    cli?: CliAdapterConfig
    graph?: GraphAdapterConfig
    security?: SecurityAdapterConfig
  }
}

interface HttpAdapterConfig {
  baseURL: string
  timeout?: number
  headers?: Record<string, string>
  auth?: {
    type: 'bearer' | 'basic'
    token?: string
    username?: string
    password?: string
  }
}

interface BrowserAdapterConfig {
  baseURL: string
  headless?: boolean
  viewport?: { width: number; height: number }
  screenshot?: 'always' | 'only-on-failure' | 'never'
  video?: 'on' | 'off' | 'retain-on-failure'
}

interface CliAdapterConfig {
  workingDir?: string
  shell?: string
  timeout?: number
  env?: Record<string, string>
}

interface GraphAdapterConfig {
  uri: string
  username: string
  password: string
  database?: string
}

interface SecurityAdapterConfig {
  zapUrl: string
  zapApiKey?: string
}
```

---

## 4. TestWorld Class

The TestWorld is the shared context for each scenario, holding adapter instances and variables.

### 4.1 World Interface

```typescript
// support/world.ts
import { World, IWorldOptions } from '@cucumber/cucumber'
import type {
  HttpAdapter,
  BrowserAdapter,
  CliAdapter,
  GraphAdapter,
  SecurityAdapter
} from 'exo-bdd'

export interface TestWorld extends World {
  // Adapters (initialized in hooks)
  http: HttpAdapter
  browser: BrowserAdapter
  cli: CliAdapter
  graph: GraphAdapter
  security: SecurityAdapter
  
  // Shared state
  variables: Map<string, unknown>
  
  // Helper methods
  setVariable(name: string, value: unknown): void
  getVariable<T>(name: string): T
  interpolate(text: string): string
}
```

### 4.2 World Implementation

```typescript
// support/world.ts
import { World, IWorldOptions } from '@cucumber/cucumber'
import type { HttpAdapter, BrowserAdapter, CliAdapter, GraphAdapter, SecurityAdapter } from 'exo-bdd'

export class TestWorld extends World {
  http!: HttpAdapter
  browser!: BrowserAdapter
  cli!: CliAdapter
  graph!: GraphAdapter
  security!: SecurityAdapter
  
  variables: Map<string, unknown> = new Map()
  
  constructor(options: IWorldOptions) {
    super(options)
  }
  
  setVariable(name: string, value: unknown): void {
    this.variables.set(name, value)
  }
  
  getVariable<T>(name: string): T {
    if (!this.variables.has(name)) {
      throw new Error(`Variable "${name}" is not defined`)
    }
    return this.variables.get(name) as T
  }
  
  interpolate(text: string): string {
    return text.replace(/\$\{(\w+)\}/g, (_, name) => {
      return String(this.getVariable(name))
    })
  }
}
```

---

## 5. Hooks & Lifecycle

### 5.1 Lifecycle Overview

```
BeforeAll       → Load config, create adapter instances
  Before        → Attach adapters to World, per-scenario setup
    Steps...    → Test execution
  After         → Per-scenario cleanup (screenshots, rollback)
AfterAll        → Dispose all adapters, close connections
```

### 5.2 Hooks Implementation

```typescript
// support/hooks.ts
import { BeforeAll, AfterAll, Before, After, setWorldConstructor, Status } from '@cucumber/cucumber'
import { loadConfig, createAdapters, Adapters } from 'exo-bdd'
import { TestWorld } from './world'

setWorldConstructor(TestWorld)

let adapters: Adapters

BeforeAll(async function () {
  const config = await loadConfig()
  adapters = await createAdapters(config)
})

Before(async function (this: TestWorld) {
  // Attach adapters to world instance
  this.http = adapters.http
  this.browser = adapters.browser
  this.cli = adapters.cli
  this.graph = adapters.graph
  this.security = adapters.security
  
  // Reset per-scenario state
  this.variables.clear()
})

After(async function (this: TestWorld, scenario) {
  // Capture screenshot on failure
  if (scenario.result?.status === Status.FAILED && this.browser) {
    const screenshot = await this.browser.screenshot()
    this.attach(screenshot, 'image/png')
  }
  
  // Browser cleanup
  await this.browser?.clearContext()
})

AfterAll(async function () {
  await adapters?.dispose()
})
```

### 5.3 Tagged Hooks

```typescript
// Run only before @authenticated scenarios
Before({ tags: '@authenticated' }, async function (this: TestWorld) {
  await this.http.post('/auth/login', {
    email: 'test@example.com',
    password: 'password123'
  })
  this.setVariable('auth_token', this.http.body.token)
  this.http.setBearerToken(this.getVariable('auth_token'))
})

// Run only after @database scenarios
After({ tags: '@database' }, async function (this: TestWorld) {
  await this.graph.query('MATCH (n:TestData) DELETE n')
})
```

---

## 6. Adapters

### 6.1 HTTP Adapter

Handles REST API testing using Playwright's APIRequestContext.

#### Interface

```typescript
interface HttpAdapter {
  // Configuration
  readonly config: HttpAdapterConfig
  
  // Request building (chainable, reset after each request)
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
  request(method: string, path: string, body?: unknown): Promise<void>
  
  // Response accessors (from last request)
  readonly response: APIResponse
  readonly status: number
  readonly statusText: string
  readonly headers: Record<string, string>
  readonly body: unknown
  readonly text: string
  readonly responseTime: number
  
  // Utilities
  getBodyPath(jsonPath: string): unknown
  
  // Lifecycle
  dispose(): Promise<void>
}
```

#### Configuration

```typescript
interface HttpAdapterConfig {
  baseURL: string
  timeout?: number              // Default: 30000
  headers?: Record<string, string>
  auth?: {
    type: 'bearer' | 'basic'
    token?: string
    username?: string
    password?: string
  }
}
```

#### Core Step Definitions

```gherkin
# Request Building
Given I set header {string} to {string}
Given I set query param {string} to {string}
Given I set bearer token to {string}
Given I set basic auth with username {string} and password {string}

# HTTP Requests
When I GET {string}
When I POST to {string}
When I POST to {string} with body:
When I PUT to {string} with body:
When I PATCH to {string} with body:
When I DELETE {string}
When I send a {word} request to {string}
When I send a {word} request to {string} with body:

# Response Status
Then the response status should be {int}
Then the response status should be between {int} and {int}
Then the response should be successful
Then the response should be a client error
Then the response should be a server error

# Response Headers
Then the response header {string} should equal {string}
Then the response header {string} should contain {string}
Then the response header {string} should exist
Then the response should have content-type {string}

# Response Body
Then the response body should equal:
Then the response body should contain {string}
Then the response body should match schema {string}

# JSONPath Assertions
Then the response body path {string} should equal {string}
Then the response body path {string} should equal {int}
Then the response body path {string} should be true
Then the response body path {string} should be false
Then the response body path {string} should be null
Then the response body path {string} should exist
Then the response body path {string} should not exist
Then the response body path {string} should contain {string}
Then the response body path {string} should match {string}
Then the response body path {string} should have {int} items

# Response Time
Then the response time should be less than {int} ms

# Variable Storage
And I store response body path {string} as {string}
And I store response header {string} as {string}
```

#### Example Usage

```gherkin
Feature: User API

  Scenario: Create and retrieve a user
    Given I set header "Content-Type" to "application/json"
    When I POST to "/users" with body:
      """json
      {
        "name": "John Doe",
        "email": "john@example.com"
      }
      """
    Then the response status should be 201
    And the response body path "$.id" should exist
    And I store response body path "$.id" as "user_id"
    
    When I GET "/users/${user_id}"
    Then the response status should be 200
    And the response body path "$.name" should equal "John Doe"
    And the response body path "$.email" should equal "john@example.com"
```

---

### 6.2 Browser Adapter

Handles Web UI testing using Playwright.

#### Interface

```typescript
interface BrowserAdapter {
  // Configuration
  readonly config: BrowserAdapterConfig
  
  // Page access
  readonly page: Page
  
  // Navigation
  goto(path: string): Promise<void>
  reload(): Promise<void>
  goBack(): Promise<void>
  goForward(): Promise<void>
  
  // Interactions
  click(selector: string): Promise<void>
  doubleClick(selector: string): Promise<void>
  fill(selector: string, value: string): Promise<void>
  clear(selector: string): Promise<void>
  selectOption(selector: string, value: string): Promise<void>
  check(selector: string): Promise<void>
  uncheck(selector: string): Promise<void>
  press(key: string): Promise<void>
  type(selector: string, text: string): Promise<void>
  hover(selector: string): Promise<void>
  focus(selector: string): Promise<void>
  
  // File upload
  uploadFile(selector: string, filePath: string): Promise<void>
  
  // Waiting
  waitForSelector(selector: string, options?: WaitOptions): Promise<void>
  waitForNavigation(): Promise<void>
  waitForLoadState(state?: 'load' | 'domcontentloaded' | 'networkidle'): Promise<void>
  waitForTimeout(ms: number): Promise<void>
  
  // Assertions (Playwright expect)
  expect: typeof expect
  
  // Information
  url(): string
  title(): Promise<string>
  textContent(selector: string): Promise<string | null>
  getAttribute(selector: string, name: string): Promise<string | null>
  isVisible(selector: string): Promise<boolean>
  isEnabled(selector: string): Promise<boolean>
  isChecked(selector: string): Promise<boolean>
  
  // Screenshots
  screenshot(options?: ScreenshotOptions): Promise<Buffer>
  
  // Context management
  clearContext(): Promise<void>
  
  // Lifecycle
  dispose(): Promise<void>
}
```

#### Core Step Definitions

```gherkin
# Navigation
Given I am on {string}
Given I navigate to {string}
When I navigate to {string}
When I reload the page
When I go back
When I go forward

# Clicking
When I click {string}
When I click the {string} button
When I click the {string} link
When I click the {string} element
When I click {string} at position {int},{int}
When I double-click {string}

# Form Inputs
When I fill {string} with {string}
When I clear {string}
When I type {string} into {string}
When I select {string} from {string}
When I check {string}
When I uncheck {string}
When I press {string}
When I upload {string} to {string}

# Hovering/Focus
When I hover over {string}
When I focus on {string}

# Browser Dialogs (confirm/alert/prompt)
When I accept the next browser dialog
When I dismiss the next browser dialog

# Waiting
When I wait for {string} to be visible
When I wait for {string} to be hidden
When I wait for {int} seconds
When I wait for the page to load
When I wait for network idle

# Visibility Assertions
Then I should see {string}
Then I should not see {string}
Then {string} should be visible
Then {string} should be hidden
Then {string} should exist
Then {string} should not exist

# State Assertions
Then {string} should be enabled
Then {string} should be disabled
Then {string} should be checked
Then {string} should not be checked

# Content Assertions
Then {string} should have text {string}
Then {string} should contain text {string}
Then {string} should have value {string}
Then {string} should have attribute {string} with value {string}
Then {string} should have class {string}

# Page Assertions
Then the page title should be {string}
Then the page title should contain {string}
Then the URL should be {string}
Then the URL should contain {string}

# Count Assertions
Then there should be {int} {string} elements

# Screenshots
Then I take a screenshot
Then I take a screenshot of {string}

# Variable Storage
And I store the text of {string} as {string}
And I store the value of {string} as {string}
And I store the URL as {string}
```

#### Example Usage

```gherkin
Feature: User Login

  Scenario: Successful login
    Given I navigate to "/login"
    When I fill "Email" with "user@example.com"
    And I fill "Password" with "password123"
    And I click the "Sign In" button
    Then I should see "Welcome back"
    And the URL should contain "/dashboard"

  Scenario: Form validation
    Given I navigate to "/login"
    When I click the "Sign In" button
    Then I should see "Email is required"
    And I should see "Password is required"
```

---

### 6.3 CLI Adapter

Handles command-line application testing using Bun's shell API.

#### Interface

```typescript
interface CliAdapter {
  // Configuration
  readonly config: CliAdapterConfig
  
  // Environment
  setEnv(name: string, value: string): this
  setEnvs(env: Record<string, string>): this
  clearEnv(name: string): this
  setWorkingDir(dir: string): this
  
  // Execution
  run(command: string): Promise<CommandResult>
  runWithStdin(command: string, stdin: string): Promise<CommandResult>
  runWithTimeout(command: string, timeoutMs: number): Promise<CommandResult>
  
  // Result accessors (from last command)
  readonly result: CommandResult
  readonly stdout: string
  readonly stderr: string
  readonly exitCode: number
  readonly duration: number
  
  // Utilities
  stdoutLine(lineNumber: number): string
  stdoutMatching(pattern: RegExp): string | null
  
  // Lifecycle
  dispose(): Promise<void>
}

interface CommandResult {
  stdout: string
  stderr: string
  exitCode: number
  duration: number
}
```

#### Core Step Definitions

```gherkin
# Environment Setup
Given I set environment variable {string} to {string}
Given I clear environment variable {string}
Given I set working directory to {string}

# Command Execution
When I run {string}
When I run {string} with timeout {int} seconds
When I run {string} with stdin:

# Exit Code Assertions
Then the exit code should be {int}
Then the exit code should not be {int}
Then the command should succeed
Then the command should fail

# Stdout Assertions
Then stdout should contain {string}
Then stdout should not contain {string}
Then stdout should equal:
Then stdout should match {string}
Then stdout should be empty
Then stdout line {int} should equal {string}
Then stdout line {int} should contain {string}

# Stderr Assertions
Then stderr should contain {string}
Then stderr should not contain {string}
Then stderr should be empty
Then stderr should match {string}

# Duration Assertions
Then the command should complete within {int} seconds

# Variable Storage
And I store stdout as {string}
And I store stdout line {int} as {string}
And I store stdout matching {string} as {string}
```

#### Example Usage

```gherkin
Feature: CLI Application

  Scenario: Version command
    When I run "myapp --version"
    Then the exit code should be 0
    And stdout should match "^v\\d+\\.\\d+\\.\\d+$"

  Scenario: Create user command
    When I run "myapp user create --email=test@example.com"
    Then the command should succeed
    And stdout should contain "User created successfully"
    And I store stdout matching "ID: (\\w+)" as "user_id"
    
    When I run "myapp user get ${user_id}"
    Then stdout should contain "test@example.com"

  Scenario: Invalid input handling
    When I run "myapp user create --email=invalid"
    Then the exit code should be 1
    And stderr should contain "Invalid email format"
```

---

### 6.4 Graph Database Adapter

Handles codebase architecture testing using Neo4j.

#### Expected Graph Schema

The graph database should be populated (externally) with the following schema:

```
Nodes:
  (:File {path: string, name: string, extension: string})
  (:Directory {path: string, name: string})
  (:Class {name: string, fqn: string, abstract: boolean})
  (:Interface {name: string, fqn: string})
  (:Function {name: string, fqn: string})
  (:Type {name: string, fqn: string})
  (:Module {name: string, path: string})
  (:Layer {name: string})

Relationships:
  (:File)-[:IN]->(:Directory)
  (:Directory)-[:IN]->(:Directory)
  (:Class)-[:DEFINED_IN]->(:File)
  (:Interface)-[:DEFINED_IN]->(:File)
  (:Function)-[:DEFINED_IN]->(:File)
  (:Class)-[:IMPORTS]->(:Class|Interface|Function|Type)
  (:Class)-[:IMPLEMENTS]->(:Interface)
  (:Class)-[:EXTENDS]->(:Class)
  (:Module)-[:DEPENDS_ON]->(:Module)
  (:File|Class|Interface|Function|Module)-[:BELONGS_TO]->(:Layer)
```

#### Interface

```typescript
interface GraphAdapter {
  // Configuration
  readonly config: GraphAdapterConfig
  
  // Connection
  connect(): Promise<void>
  disconnect(): Promise<void>
  
  // Raw Cypher queries
  query<T = Record<string, unknown>>(
    cypher: string,
    params?: Record<string, unknown>
  ): Promise<T[]>
  
  // Result accessors (from last query)
  readonly result: QueryResult
  readonly records: Record<string, unknown>[]
  readonly count: number
  
  // High-level helpers: Layers
  getLayer(name: string): Promise<LayerInfo>
  getNodesInLayer(layer: string, type?: NodeType): Promise<Node[]>
  getLayerDependencies(from: string, to: string): Promise<Dependency[]>
  
  // High-level helpers: Dependencies
  getDependencies(nodeFqn: string): Promise<Dependency[]>
  getDependents(nodeFqn: string): Promise<Dependency[]>
  findCircularDependencies(): Promise<Cycle[]>
  findCircularDependenciesInLayer(layer: string): Promise<Cycle[]>
  
  // High-level helpers: Interfaces
  getClassesImplementing(interfaceName: string): Promise<Node[]>
  getClassesNotImplementingAnyInterface(): Promise<Node[]>
  getInterfacesInLayer(layer: string): Promise<Node[]>
  
  // High-level helpers: Search
  findNodes(pattern: string, type?: NodeType): Promise<Node[]>
  findNodesByLayer(layer: string, type?: NodeType): Promise<Node[]>
  
  // Lifecycle
  dispose(): Promise<void>
}

type NodeType = 'class' | 'interface' | 'function' | 'file' | 'module'

interface Node {
  name: string
  fqn: string
  type: NodeType
  layer?: string
  file?: string
}

interface Dependency {
  from: Node
  to: Node
  type: 'imports' | 'implements' | 'extends' | 'depends_on'
}

interface Cycle {
  nodes: Node[]
  path: string
}

interface LayerInfo {
  name: string
  nodeCount: number
  classCount: number
  interfaceCount: number
}
```

#### Core Step Definitions

```gherkin
# Layer Selection
Given the layer {string}
Given all nodes in layer {string}
Given all classes in layer {string}
Given all interfaces in layer {string}

# Node Selection
Given all classes matching {string}
Given all classes in {string}
Given all interfaces in {string}
Given the class {string}
Given the module {string}

# Layer Dependency Assertions
Then it should not depend on layer {string}
Then it should only depend on layer {string}
Then it should only depend on layers:
Then it may depend on layer {string}
Then dependencies on layer {string} should only be interfaces

# Circular Dependency Detection
When I check for circular dependencies
When I check for circular dependencies in layer {string}
Then no cycles should be found
Then there should be no circular dependencies

# Interface Assertions
Then each should implement an interface
Then each should implement an interface from layer {string}
Then each should implement an interface matching {string}
Then classes implementing {string} should be in layer {string}

# Import Assertions
Then imports should only be interfaces
Then there should be no direct imports from layer {string}

# Raw Cypher Queries
When I query:
Then the result should be empty
Then the result should have {int} rows
Then the result should have at least {int} rows
Then the result path {string} should equal {string}
Then the result path {string} should contain {string}

# Variable Storage
And I store the result as {string}
And I store the result count as {string}
```

#### Example Usage

```gherkin
Feature: Clean Architecture Compliance

  @architecture
  Scenario: Domain layer has no outward dependencies
    Given the layer "domain"
    Then it should not depend on layer "application"
    And it should not depend on layer "infrastructure"
    And it should not depend on layer "presentation"

  @architecture
  Scenario: Application layer only depends on domain
    Given the layer "application"
    Then it may depend on layer "domain"
    But it should not depend on layer "infrastructure"
    And it should not depend on layer "presentation"

  @architecture
  Scenario: Infrastructure depends on application via interfaces only
    Given the layer "infrastructure"
    Then dependencies on layer "application" should only be interfaces

  @architecture
  Scenario: No circular dependencies in the codebase
    When I check for circular dependencies
    Then no cycles should be found

  @architecture
  Scenario: All repositories implement interfaces
    Given all classes matching "*Repository" in layer "infrastructure"
    Then each should implement an interface from layer "application"

  @architecture
  Scenario: Use cases are properly abstracted
    Given all classes in "application/use-cases"
    Then each should implement an interface

  @architecture
  Scenario: Controllers don't import infrastructure directly
    Given the layer "presentation"
    Then there should be no direct imports from layer "infrastructure"

  @architecture
  Scenario: Custom query - find framework dependencies in domain
    When I query:
      """cypher
      MATCH (d:Class)-[:IMPORTS]->(ext:Class)
      WHERE d.layer = 'domain' 
        AND NOT ext.fqn STARTS WITH 'src/'
        AND NOT ext.fqn STARTS WITH '@types/'
      RETURN d.name as class, ext.fqn as external_dependency
      """
    Then the result should be empty
```

---

### 6.5 Security Adapter

Handles security/penetration testing using OWASP ZAP.

#### Interface

```typescript
interface SecurityAdapter {
  // Configuration
  readonly config: SecurityAdapterConfig
  
  // Scanning
  spider(url: string): Promise<SpiderResult>
  activeScan(url: string): Promise<ScanResult>
  passiveScan(url: string): Promise<ScanResult>
  ajaxSpider(url: string): Promise<SpiderResult>
  
  // Result accessors
  readonly alerts: Alert[]
  readonly alertCount: number
  
  // Alert filtering
  getAlertsByRisk(risk: RiskLevel): Alert[]
  getAlertsByConfidence(confidence: ConfidenceLevel): Alert[]
  getAlertsByType(alertType: string): Alert[]
  
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

type RiskLevel = 'High' | 'Medium' | 'Low' | 'Informational'
type ConfidenceLevel = 'High' | 'Medium' | 'Low' | 'Confirmed'

interface Alert {
  name: string
  risk: RiskLevel
  confidence: ConfidenceLevel
  description: string
  url: string
  solution: string
  reference: string
  cweid: string
  wascid: string
}

interface SpiderResult {
  urlsFound: number
  duration: number
}

interface ScanResult {
  alertCount: number
  duration: number
  progress: number
}

interface HeaderCheckResult {
  headers: Record<string, string>
  missing: string[]
  issues: string[]
}

interface SslCheckResult {
  valid: boolean
  expiresAt: Date
  issuer: string
  issues: string[]
}
```

#### Core Step Definitions

```gherkin
# Session Management
Given a new ZAP session

# Spidering
When I spider {string}
When I ajax spider {string}
Then the spider should find at least {int} URLs

# Scanning
When I run a passive scan on {string}
When I run an active scan on {string}
When I run a baseline scan on {string}

# Alert Assertions (by risk)
Then no high risk alerts should be found
Then no medium or higher risk alerts should be found
Then there should be no critical vulnerabilities
Then alerts should not exceed risk level {string}

# Alert Assertions (by count)
Then there should be {int} alerts
Then there should be less than {int} alerts
Then there should be no alerts of type {string}

# Specific Vulnerability Checks
When I check {string} for security headers
Then the security headers should include {string}
Then Content-Security-Policy should be present
Then X-Frame-Options should be set to {string}
Then Strict-Transport-Security should be present

When I check SSL certificate for {string}
Then the SSL certificate should be valid
Then the SSL certificate should not expire within {int} days

# Reporting
And I save the security report to {string}
And I save the security report as JSON to {string}

# Detailed inspection
Then I should see the alert details
And I store the alerts as {string}
```

#### Example Usage

```gherkin
Feature: Security Testing

  @security
  Scenario: No high-risk vulnerabilities in API
    Given a new ZAP session
    When I spider "http://localhost:3000/api"
    And I run an active scan on "http://localhost:3000/api"
    Then no high risk alerts should be found
    And no medium or higher risk alerts should be found

  @security
  Scenario: Security headers are properly configured
    When I check "http://localhost:3000" for security headers
    Then Content-Security-Policy should be present
    And X-Frame-Options should be set to "DENY"
    And Strict-Transport-Security should be present
    And the security headers should include "X-Content-Type-Options"

  @security
  Scenario: SSL certificate is valid
    When I check SSL certificate for "https://example.com"
    Then the SSL certificate should be valid
    And the SSL certificate should not expire within 30 days

  @security
  Scenario: OWASP Top 10 baseline scan
    Given a new ZAP session
    When I run a baseline scan on "http://localhost:3000"
    Then there should be no alerts of type "SQL Injection"
    And there should be no alerts of type "Cross Site Scripting"
    And there should be no alerts of type "Remote File Inclusion"
    And I save the security report to "reports/security.html"
```

---

## 7. Variables & State

### 7.1 Variable Scopes

| Scope | Lifetime | Usage |
|-------|----------|-------|
| Scenario | Single scenario | `this.variables` in World |
| Environment | Test run | `process.env` |

### 7.2 Storing Variables

```gherkin
# From HTTP responses
And I store response body path "$.id" as "user_id"
And I store response header "X-Request-Id" as "request_id"

# From browser
And I store the text of "#user-name" as "username"
And I store the URL as "current_url"

# From CLI
And I store stdout as "output"
And I store stdout line 1 as "first_line"

# From graph queries
And I store the result count as "violation_count"
```

### 7.3 Using Variables

Variables are interpolated in step arguments using `${name}` syntax:

```gherkin
When I GET "/users/${user_id}"
And I fill "Confirmation" with "${confirmation_code}"
When I run "myapp delete ${resource_id}"
```

### 7.4 Built-in Variables

The framework provides some built-in variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `${timestamp}` | Unix timestamp (seconds) | `1699876543` |
| `${timestamp_ms}` | Unix timestamp (milliseconds) | `1699876543210` |
| `${iso_date}` | ISO 8601 date | `2024-01-15T10:30:00Z` |
| `${uuid}` | Random UUID v4 | `f47ac10b-58cc...` |
| `${random_int}` | Random integer 0-999999 | `482910` |
| `${random_string}` | Random 8-char alphanumeric | `a8Bx92Kp` |
| `${random_email}` | Random email address | `test_a8bx@example.com` |

---

## 8. Writing Custom Steps

### 8.1 Step Definition Structure

```typescript
// steps/custom/my-steps.ts
import { Given, When, Then } from '@cucumber/cucumber'
import { TestWorld } from '../../support/world'

// Use function() syntax, not arrow functions (need 'this' context)
When<TestWorld>(
  'I create a user with email {string}',
  async function (email: string) {
    await this.http.post('/users', { email })
  }
)

Then<TestWorld>(
  'the user should have role {string}',
  async function (expectedRole: string) {
    const role = this.http.getBodyPath('$.role')
    expect(role).toBe(expectedRole)
  }
)
```

### 8.2 Cucumber Expression Parameters

| Parameter | Matches | Example |
|-----------|---------|---------|
| `{string}` | Quoted string | `"hello"` or `'hello'` |
| `{int}` | Integer (also used for numeric assertions) | `42`, `-7` |
| `{word}` | Single word (no spaces) | `GET`, `admin` |
| `{}` | Any text (anonymous) | Anything |

### 8.3 Doc Strings

```typescript
When<TestWorld>(
  'I POST to {string} with body:',
  async function (path: string, docString: string) {
    const body = JSON.parse(this.interpolate(docString))
    await this.http.post(path, body)
  }
)
```

Usage:
```gherkin
When I POST to "/users" with body:
  """json
  {
    "name": "John",
    "email": "${random_email}"
  }
  """
```

### 8.4 Data Tables

```typescript
Given<TestWorld>(
  'the following users exist:',
  async function (dataTable: DataTable) {
    const users = dataTable.hashes() // [{name: "John", email: "..."}, ...]
    for (const user of users) {
      await this.http.post('/users', user)
    }
  }
)
```

Usage:
```gherkin
Given the following users exist:
  | name  | email              | role  |
  | John  | john@example.com   | admin |
  | Jane  | jane@example.com   | user  |
```

### 8.5 LLM Guidelines for Step Definitions

When generating step definitions, follow these patterns:

1. **Always use `function()` syntax** - Arrow functions lose `this` context
   ```typescript
   // Correct
   When('...', async function() { this.http... })
   
   // Wrong - 'this' is undefined
   When('...', async () => { this.http... })
   ```

2. **Use Cucumber Expressions over regex** - More readable, fewer errors
   ```typescript
   // Preferred
   When('I GET {string}', ...)
   
   // Avoid
   When(/^I GET "([^"]*)"$/, ...)
   ```

3. **Keep steps focused** - One action or assertion per step

4. **Use adapter methods** - Don't bypass adapters with raw library calls

5. **Handle interpolation** - Use `this.interpolate()` for doc strings
   ```typescript
   const body = JSON.parse(this.interpolate(docString))
   ```

6. **Type the World** - Always use `<TestWorld>` generic
   ```typescript
   When<TestWorld>('...', async function() { ... })
   ```

---

## 9. Running Tests

### 9.1 Basic Commands

```bash
# Run all tests
npx cucumber-js

# Run specific feature file
npx cucumber-js features/api/users.feature

# Run multiple feature files
npx cucumber-js features/api/*.feature features/web/login.feature

# Run specific scenario by name
npx cucumber-js --name "Successful login"
```

### 9.2 Tag Filtering

```bash
# Run scenarios with tag
npx cucumber-js --tags "@smoke"

# Run scenarios with multiple tags (AND)
npx cucumber-js --tags "@api and @critical"

# Run scenarios with either tag (OR)
npx cucumber-js --tags "@smoke or @regression"

# Exclude tags
npx cucumber-js --tags "not @slow"

# Complex expressions
npx cucumber-js --tags "(@api or @web) and not @wip"
```

### 9.3 Parallel Execution

```bash
# Run scenarios in parallel (4 workers)
npx cucumber-js --parallel 4

# Run with specific worker count from env
CUCUMBER_PARALLEL=8 npx cucumber-js --parallel
```

### 9.4 Reporting

```bash
# Multiple formatters
npx cucumber-js --format progress --format html:reports/cucumber.html

# JSON output for CI
npx cucumber-js --format json:reports/results.json

# JUnit for CI pipelines
npx cucumber-js --format junit:reports/junit.xml
```

### 9.5 Environment Variables

| Variable | Description |
|----------|-------------|
| `API_URL` | Base URL for HTTP adapter |
| `APP_URL` | Base URL for browser adapter |
| `NEO4J_URI` | Neo4j connection URI |
| `NEO4J_USER` | Neo4j username |
| `NEO4J_PASSWORD` | Neo4j password |
| `ZAP_URL` | OWASP ZAP API URL |
| `ZAP_API_KEY` | OWASP ZAP API key |
| `CI` | Set to "true" for headless browser |

### 9.6 Example npm Scripts

```json
{
  "scripts": {
    "test": "cucumber-js",
    "test:api": "cucumber-js --tags @api",
    "test:web": "cucumber-js --tags @web",
    "test:arch": "cucumber-js --tags @architecture",
    "test:security": "cucumber-js --tags @security",
    "test:smoke": "cucumber-js --tags @smoke",
    "test:ci": "cucumber-js --parallel 4 --format json:reports/results.json"
  }
}
```

---

## 10. Appendix: Core Step Reference

### HTTP Steps

| Step | Description |
|------|-------------|
| `Given I set header {string} to {string}` | Set request header |
| `Given I set query param {string} to {string}` | Set query parameter |
| `Given I set bearer token to {string}` | Set Authorization header |
| `Given I set basic auth with username {string} and password {string}` | Set basic auth |
| `When I GET {string}` | Send GET request |
| `When I POST to {string}` | Send POST without body |
| `When I POST to {string} with body:` | Send POST with JSON body |
| `When I POST raw to {string} with body:` | Send POST with raw string body (no JSON parsing) |
| `When I PUT to {string} with body:` | Send PUT with JSON body |
| `When I PATCH to {string} with body:` | Send PATCH with JSON body |
| `When I DELETE {string}` | Send DELETE request |
| `Then the response status should be {int}` | Assert status code |
| `Then the response body path {string} should equal {string}` | Assert JSONPath value |
| `Then the response body path {string} should exist` | Assert JSONPath exists |
| `And I store response body path {string} as {string}` | Store value in variable |

### Browser Steps

| Step | Description |
|------|-------------|
| `Given I navigate to {string}` | Navigate to URL/path |
| `When I click {string}` | Click element (text/selector) |
| `When I click the {string} button` | Click button by text |
| `When I click {string} at position {int},{int}` | Click at specific x,y within element |
| `When I fill {string} with {string}` | Fill input field |
| `When I select {string} from {string}` | Select dropdown option |
| `When I check {string}` | Check checkbox |
| `When I wait for {string} to be visible` | Wait for element |
| `Then I should see {string}` | Assert text visible |
| `Then {string} should be visible` | Assert element visible |
| `Then the URL should contain {string}` | Assert URL |
| `And I store the text of {string} as {string}` | Store element text |
| `When I accept the next browser dialog` | Accept next confirm/alert dialog |
| `When I dismiss the next browser dialog` | Dismiss next confirm/alert dialog |

### CLI Steps

| Step | Description |
|------|-------------|
| `Given I set environment variable {string} to {string}` | Set env var |
| `When I run {string}` | Execute command |
| `When I run {string} with stdin:` | Execute with stdin |
| `Then the exit code should be {int}` | Assert exit code |
| `Then the command should succeed` | Assert exit code 0 |
| `Then stdout should contain {string}` | Assert stdout content |
| `Then stderr should be empty` | Assert no stderr |
| `And I store stdout as {string}` | Store stdout |

### Graph Steps

| Step | Description |
|------|-------------|
| `Given the layer {string}` | Select layer for assertions |
| `Given all classes in layer {string}` | Select classes in layer |
| `Then it should not depend on layer {string}` | Assert no layer dependency |
| `Then each should implement an interface` | Assert interface implementation |
| `When I check for circular dependencies` | Find cycles |
| `Then no cycles should be found` | Assert no cycles |
| `When I query:` | Execute raw Cypher |
| `Then the result should be empty` | Assert empty result |

### Security Steps

| Step | Description |
|------|-------------|
| `Given a new ZAP session` | Start fresh session |
| `When I spider {string}` | Spider target URL |
| `When I run an active scan on {string}` | Active vulnerability scan |
| `Then no high risk alerts should be found` | Assert no high-risk issues |
| `When I check {string} for security headers` | Check HTTP headers |
| `Then Content-Security-Policy should be present` | Assert CSP header |
| `When I check SSL certificate for {string}` | Check SSL cert |
| `And I save the security report to {string}` | Generate report |

---

*This specification is a living document. Version 0.2.0*
