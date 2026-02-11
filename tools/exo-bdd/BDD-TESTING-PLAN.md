# BDD Testing Plan: Exo BDD Framework

**Version:** 1.0.0
**Status:** Draft
**Framework:** `bun:test`
**Mocking:** All infrastructure adapter tests use mock/stub implementations (no external services required)

---

## Document Overview

This testing plan covers every layer of the Exo BDD framework organized by implementation phase from `IMPLEMENTATION-PLAN.md`. All infrastructure adapter tests use **mock/stub implementations** to avoid requiring external services (Playwright, Neo4j, OWASP ZAP). Tests use `bun:test` as the test runner.

---

## Test File Structure

```
tests/
├── domain/
│   ├── errors.test.ts                    # (exists) Domain errors
│   ├── value-objects.test.ts             # (exists) RiskLevel, JsonPath, NodeType
│   └── entities.test.ts                  # NEW - Entity interface contracts
├── application/
│   ├── services.test.ts                  # (exists) VariableService, InterpolationService
│   ├── config-loader.test.ts             # NEW - ConfigLoader, defineConfig
│   └── config-schema.test.ts             # NEW - Config type validation
├── infrastructure/
│   ├── cli-adapter.test.ts               # (exists) BunCliAdapter
│   ├── http-adapter.test.ts              # NEW - PlaywrightHttpAdapter (mocked)
│   ├── browser-adapter.test.ts           # NEW - PlaywrightBrowserAdapter (mocked)
│   ├── graph-adapter.test.ts             # NEW - Neo4jGraphAdapter (mocked)
│   ├── security-adapter.test.ts          # NEW - ZapSecurityAdapter (mocked)
│   └── adapter-factory.test.ts           # NEW - AdapterFactory
├── interface/
│   ├── world.test.ts                     # NEW - TestWorld
│   ├── hooks/
│   │   ├── lifecycle.test.ts             # NEW - lifecycle hooks
│   │   └── tagged.test.ts                # NEW - tagged hooks
│   └── steps/
│       ├── variables.steps.test.ts       # NEW - variable step definitions
│       ├── http-steps.test.ts            # NEW - all HTTP steps
│       ├── browser-steps.test.ts         # NEW - all browser steps
│       ├── cli-steps.test.ts             # NEW - all CLI steps
│       ├── graph-steps.test.ts           # NEW - all graph steps
│       └── security-steps.test.ts        # NEW - all security steps
└── public-api.test.ts                    # NEW - Public API exports
```

---

## Phase 1: Domain Layer Tests

### 1.1 Value Objects (`tests/domain/value-objects.test.ts`) -- EXISTS

**Current coverage**: RiskLevel (compare, isAtLeast), JsonPath (validation, toString)

**Tests to add:**

| Test | Description |
|------|-------------|
| `RiskLevel.compare('Informational', 'Low')` returns negative | Covers lowest level comparison |
| `RiskLevel.isAtLeast('Informational', 'Informational')` returns true | Edge case: equal at lowest |
| `RiskLevel constants have correct values` | Verify `RiskLevel.High === 'High'` etc. |
| `JsonPath with complex expressions` | `$.store.book[*].author`, `$..price` |
| `JsonPath with empty $ expression` | `$` alone should be valid |
| `NodeType includes all expected types` | Verify union type covers 'class', 'interface', 'function', 'file', 'module' |

### 1.2 Domain Errors (`tests/domain/errors.test.ts`) -- EXISTS

**Current coverage**: VariableNotFoundError, AdapterNotConfiguredError (code, message, inheritance)

**Tests to add:**

| Test | Description |
|------|-------------|
| `DomainError cannot be instantiated directly` | Verify abstract class behavior |
| `VariableNotFoundError with special characters in name` | `'${my.var}'` |
| `AdapterNotConfiguredError with empty string` | Edge case for adapter name |
| `Errors are serializable (JSON.stringify)` | Ensure error.message survives serialization |

### 1.3 Entities (`tests/domain/entities.test.ts`) -- NEW

Since entities are interfaces, tests validate structural contracts via type assertions and factory functions.

| Test | Description |
|------|-------------|
| `HttpResponse satisfies the interface shape` | Create object, verify all required fields (status, statusText, headers, body, text, responseTime) |
| `HttpRequest satisfies the interface shape` | Verify method, url, headers, body, queryParams |
| `CommandResult satisfies the interface shape` | Verify stdout, stderr, exitCode, duration |
| `GraphNode satisfies the interface shape` | Verify name, fqn, type; optional layer, file |
| `Dependency satisfies the interface shape` | Verify from, to, type |
| `Cycle satisfies the interface shape` | Verify nodes array, path string |
| `SecurityAlert satisfies the interface shape` | Verify name, risk, confidence, description, url, solution, cweid |
| `ScanResult satisfies the interface shape` | Verify alertCount, duration, progress |
| `SpiderResult satisfies the interface shape` | Verify urlsFound, duration |
| `HeaderCheckResult satisfies the interface shape` | Verify headers, missingHeaders |
| `SslCheckResult satisfies the interface shape` | Verify valid, errors |
| `Variable satisfies the interface shape` | Verify name, value |

---

## Phase 2: Application Layer Tests

### 2.1 VariableService (`tests/application/services.test.ts`) -- EXISTS

**Current coverage**: set/get, typed get, missing variable error, has, clear

**Tests to add:**

| Test | Description |
|------|-------------|
| `set overwrites existing variable` | Set same key twice, verify latest value |
| `get with complex object value` | Set nested object, retrieve and verify structure |
| `get with null value` | Set null explicitly, verify it returns null (not throwing) |
| `get with undefined value` | Set undefined, verify behavior |
| `has returns true after set, false after clear` | Full lifecycle test |

### 2.2 InterpolationService (`tests/application/services.test.ts`) -- EXISTS

**Current coverage**: user vars, multiple vars, timestamp, uuid, random_email, random_string, no variables, missing variable

**Tests to add:**

| Test | Description |
|------|-------------|
| `interpolates timestamp_ms as millisecond timestamp` | Verify `${timestamp_ms}` is a valid ms timestamp |
| `interpolates iso_date as ISO 8601 string` | Verify `${iso_date}` matches ISO format |
| `interpolates random_int as number between 0-999999` | Verify range |
| `preserves $$ or escaped sequences` | Verify `$${name}` doesn't interpolate |
| `handles adjacent variables` | `${a}${b}` with no separator |
| `handles variables in JSON strings` | `{"id": "${user_id}"}` |
| `each call to uuid produces unique values` | Call twice, verify different |
| `each call to random_string produces unique values` | Call twice, verify different |

### 2.3 ConfigLoader (`tests/application/config-loader.test.ts`) -- NEW

| Test | Description |
|------|-------------|
| `loadConfig loads from default path` | Mock file system, verify it loads `exo-bdd.config.ts` |
| `loadConfig loads from custom path` | Pass explicit path, verify import |
| `loadConfig throws for missing config file` | Non-existent path should throw |
| `loadConfig returns parsed ExoBddConfig` | Verify the returned shape |
| `defineConfig returns the same config object` | Identity function verification |
| `defineConfig provides type safety` | Verify TypeScript type inference (compile-time check) |

### 2.4 ConfigSchema (`tests/application/config-schema.test.ts`) -- NEW

| Test | Description |
|------|-------------|
| `ExoBddConfig with all adapters configured` | Full config object validates |
| `ExoBddConfig with no adapters` | Empty adapters object is valid |
| `ExoBddConfig with only HTTP adapter` | Partial config is valid |
| `HttpAdapterConfig requires baseURL` | Verify baseURL is mandatory |
| `HttpAdapterConfig with auth bearer config` | Verify auth.type='bearer' + token |
| `HttpAdapterConfig with auth basic config` | Verify auth.type='basic' + username/password |
| `BrowserAdapterConfig defaults` | Verify optional fields (headless, viewport, screenshot, video) |
| `CliAdapterConfig with all options` | Verify workingDir, shell, timeout, env |
| `GraphAdapterConfig requires uri, username, password` | Verify required fields |
| `SecurityAdapterConfig requires zapUrl` | Verify required field |

---

## Phase 3: Infrastructure Layer Tests

### 3.1 PlaywrightHttpAdapter (`tests/infrastructure/http-adapter.test.ts`) -- NEW

**Mocking strategy**: Mock `@playwright/test`'s `request.newContext()` to return a mock `APIRequestContext` that captures calls and returns configurable responses.

| Test | Description |
|------|-------------|
| `initialize creates API context with config` | Verify baseURL, timeout, headers passed to context |
| `setHeader stores pending header` | Set header, make request, verify header sent |
| `setHeaders stores multiple headers` | Set multiple headers at once |
| `setQueryParam appends to URL` | Verify query params appear in URL |
| `setQueryParams appends multiple params` | Verify multiple query params |
| `setBearerToken sets Authorization header` | Verify `Bearer <token>` format |
| `setBasicAuth sets Authorization header` | Verify Base64 encoded auth |
| `get sends GET request to correct URL` | Verify method and path |
| `post sends POST with body` | Verify method, path, and body data |
| `put sends PUT with body` | Verify method, path, and body data |
| `patch sends PATCH with body` | Verify method, path, and body data |
| `delete sends DELETE request` | Verify method and path |
| `response exposes status code` | Verify `.status` accessor |
| `response exposes parsed JSON body` | Verify `.body` returns parsed object |
| `response exposes raw text` | Verify `.text` returns raw response |
| `response exposes headers` | Verify `.response.headers` |
| `response captures response time` | Verify `.responseTime` >= 0 |
| `getBodyPath extracts value via JSONPath` | `$.name` returns correct value |
| `getBodyPath returns undefined for missing path` | Non-existent path behavior |
| `getBodyPath handles nested paths` | `$.data.users[0].name` |
| `getBodyPath handles array queries` | `$.items[*].id` |
| `pending headers/params reset after request` | Second request doesn't carry first's headers |
| `parseBody handles non-JSON response` | Returns text when JSON.parse fails |
| `buildUrl resolves relative paths against baseURL` | Verify URL construction |
| `dispose calls context.dispose()` | Verify cleanup |

### 3.2 PlaywrightBrowserAdapter (`tests/infrastructure/browser-adapter.test.ts`) -- NEW

**Mocking strategy**: Mock `playwright`'s `chromium.launch()` to return a mock Browser -> Context -> Page chain.

| Test | Description |
|------|-------------|
| `initialize launches chromium with headless config` | Verify headless option |
| `initialize creates context with viewport` | Verify viewport dimensions |
| `initialize creates context with baseURL` | Verify baseURL passed |
| `goto navigates page to path` | Verify `page.goto` called with path |
| `reload calls page.reload` | Verify delegation |
| `goBack calls page.goBack` | Verify delegation |
| `click delegates to page.click` | Verify selector passed |
| `fill delegates to page.fill` | Verify selector and value |
| `selectOption delegates to page.selectOption` | Verify selector and value |
| `check delegates to page.check` | Verify selector |
| `waitForSelector delegates with options` | Verify selector and state/timeout options |
| `waitForNavigation waits for networkidle` | Verify load state |
| `url returns current page URL` | Verify delegation |
| `title returns page title` | Verify delegation |
| `textContent returns element text` | Verify selector and return value |
| `isVisible returns visibility state` | Verify selector and return value |
| `screenshot returns Buffer` | Verify `page.screenshot` called |
| `clearContext clears cookies and localStorage` | Verify both clear operations |
| `dispose closes context and browser` | Verify both `.close()` called |

### 3.3 BunCliAdapter (`tests/infrastructure/cli-adapter.test.ts`) -- EXISTS

**Current coverage**: run, stderr, exit codes, duration, setEnv, setWorkingDir, result accessor, runWithStdin, chaining

**Tests to add:**

| Test | Description |
|------|-------------|
| `run with default config (no cwd, no env)` | Verify defaults from CliAdapterConfig |
| `run with config-level env vars` | Constructor config env vars are applied |
| `run with config-level workingDir` | Constructor config workingDir is applied |
| `run command with quotes and special chars` | `echo "hello 'world'"` |
| `run captures both stdout and stderr` | Command producing both streams |
| `result throws if accessed before any run` | Accessing `stdout` before first `run` |
| `runWithStdin handles multiline input` | Multi-line stdin data |
| `runWithStdin with empty stdin` | Empty string input |
| `setEnv overrides config-level env` | Instance override takes precedence |
| `setWorkingDir overrides config-level dir` | Instance override takes precedence |
| `dispose is a no-op (does not throw)` | Verify safe to call |
| `long-running command captures correct duration` | Verify timing accuracy |

### 3.4 Neo4jGraphAdapter (`tests/infrastructure/graph-adapter.test.ts`) -- NEW

**Mocking strategy**: Mock `neo4j-driver`'s `driver()`, `session()`, and `session.run()` to return configurable records.

| Test | Description |
|------|-------------|
| `connect creates driver with URI and credentials` | Verify driver creation args |
| `connect opens session with configured database` | Verify database name |
| `disconnect closes session and driver` | Verify both `.close()` called |
| `query executes Cypher and returns mapped records` | Simple query with params |
| `query with empty result returns empty array` | No records case |
| `getNodesInLayer queries correct Cypher` | Verify MATCH pattern and layer param |
| `getNodesInLayer with type filter` | Verify WHERE clause includes type |
| `getNodesInLayer without type filter` | Verify no type filtering |
| `getLayerDependencies returns dependencies between layers` | Verify DEPENDS_ON relationship query |
| `getLayerDependencies returns empty when no deps` | No cross-layer dependencies |
| `findCircularDependencies detects cycles` | Return mock cycle data |
| `findCircularDependencies returns empty when clean` | No cycles case |
| `getClassesImplementing finds implementing classes` | Verify IMPLEMENTS query |
| `getClassesImplementing returns empty for unknown interface` | No implementations |
| `dispose delegates to disconnect` | Verify disconnect called |

### 3.5 ZapSecurityAdapter (`tests/infrastructure/security-adapter.test.ts`) -- NEW

**Mocking strategy**: Mock `global.fetch` to intercept ZAP REST API calls and return configurable responses.

| Test | Description |
|------|-------------|
| `constructor stores config (zapUrl, apiKey)` | Verify config retention |
| `spider starts spider scan via API` | Verify `/JSON/spider/action/scan/` called |
| `spider polls until completion` | Verify polling with status checks |
| `spider returns urlsFound count` | Verify return value |
| `activeScan starts scan via API` | Verify `/JSON/ascan/action/scan/` called |
| `activeScan polls at 2-second intervals` | Verify polling interval |
| `activeScan refreshes alerts on completion` | Verify alerts fetched after scan |
| `passiveScan waits for queue to drain` | Verify `recordsToScan` polling |
| `alerts getter returns cached alerts` | Verify array access |
| `getAlertsByRisk filters by risk level` | Verify filtering logic |
| `getAlertsByRisk returns empty for no matches` | No alerts at specified level |
| `checkSecurityHeaders fetches and checks 7 headers` | Verify all header checks |
| `checkSecurityHeaders reports missing headers` | Some headers absent |
| `checkSecurityHeaders reports all present` | All headers present |
| `checkSslCertificate validates HTTPS URL` | Verify HTTPS fetch |
| `checkSslCertificate reports invalid cert` | Fetch fails scenario |
| `generateHtmlReport fetches and writes report` | Verify API call and `Bun.write` |
| `newSession creates fresh session` | Verify API call and alert reset |
| `dispose is a no-op` | Verify safe to call |
| `zapRequest includes API key in params` | Verify apikey query param |
| `zapRequest handles API errors` | Non-200 response handling |

### 3.6 AdapterFactory (`tests/infrastructure/adapter-factory.test.ts`) -- NEW

**Mocking strategy**: Mock all adapter constructors and their `initialize()`/`connect()` methods.

| Test | Description |
|------|-------------|
| `createAdapters with full config creates all adapters` | Verify all 5 adapters instantiated |
| `createAdapters with empty config creates no adapters` | All adapter fields undefined |
| `createAdapters with only HTTP config` | Only http adapter created |
| `createAdapters with only browser config` | Only browser adapter created |
| `createAdapters with only CLI config` | Only cli adapter created |
| `createAdapters with only graph config` | Only graph adapter created |
| `createAdapters with only security config` | Only security adapter created |
| `createAdapters calls initialize on HTTP adapter` | Verify `http.initialize()` called |
| `createAdapters calls initialize on browser adapter` | Verify `browser.initialize()` called |
| `createAdapters calls connect on graph adapter` | Verify `graph.connect()` called |
| `dispose calls dispose on all created adapters` | Verify all `.dispose()` called |
| `dispose handles undefined adapters gracefully` | Partial config dispose doesn't throw |
| `dispose calls all dispose in parallel` | Verify `Promise.all` behavior |

---

## Phase 4: Interface Layer Tests

### 4.1 TestWorld (`tests/interface/world.test.ts`) -- NEW

**Mocking strategy**: Mock Cucumber's `World` constructor and provide a mock `IWorldOptions`.

| Test | Description |
|------|-------------|
| `constructor creates VariableService and InterpolationService` | Verify internal services initialized |
| `setVariable delegates to VariableService.set` | Set and verify retrieval |
| `getVariable delegates to VariableService.get` | Get stored variable |
| `getVariable throws VariableNotFoundError for missing` | Verify error propagation |
| `hasVariable returns true for existing` | After setVariable, hasVariable returns true |
| `hasVariable returns false for missing` | Before setVariable, hasVariable returns false |
| `interpolate replaces variables in text` | `${name}` replaced with stored value |
| `interpolate handles built-in variables` | `${uuid}`, `${timestamp}` etc. |
| `reset clears all variables` | After reset, previously set vars are gone |
| `adapters are assignable` | Verify http, browser, cli, graph, security can be assigned |

### 4.2 Lifecycle Hooks (`tests/interface/hooks/lifecycle.test.ts`) -- NEW

**Mocking strategy**: Mock `@cucumber/cucumber`'s hook registration functions (`BeforeAll`, `Before`, `After`, `AfterAll`, `setWorldConstructor`). Capture the registered callbacks and invoke them with mock contexts.

| Test | Description |
|------|-------------|
| `setWorldConstructor is called with TestWorld` | Verify registration |
| `BeforeAll loads config and creates adapters` | Verify `loadConfig` + `createAdapters` called |
| `Before attaches adapters to world instance` | Verify world.http, world.browser, etc. set |
| `Before calls world.reset()` | Verify state reset each scenario |
| `Before skips undefined adapters` | Only configured adapters attached |
| `After captures screenshot on failure when browser available` | Verify screenshot + attach |
| `After does not capture screenshot when no browser` | No browser adapter, no error |
| `After does not capture screenshot on success` | Passing scenario skips screenshot |
| `After clears browser context` | Verify `clearContext()` called |
| `AfterAll disposes all adapters` | Verify `adapters.dispose()` called |
| `AfterAll handles null adapters gracefully` | No adapters initialized case |

### 4.3 Tagged Hooks (`tests/interface/hooks/tagged.test.ts`) -- NEW

| Test | Description |
|------|-------------|
| `@http Before hook throws if http adapter missing` | Error message mentions HTTP config |
| `@http Before hook passes if http adapter present` | No error thrown |
| `@browser Before hook throws if browser adapter missing` | Error message mentions browser config |
| `@browser Before hook passes if browser adapter present` | No error thrown |
| `@cli Before hook throws if cli adapter missing` | Error message mentions CLI config |
| `@cli Before hook passes if cli adapter present` | No error thrown |
| `@graph Before hook throws if graph adapter missing` | Error message mentions graph config |
| `@graph Before hook passes if graph adapter present` | No error thrown |
| `@security Before hook throws if security adapter missing` | Error message mentions security config |
| `@security Before hook passes if security adapter present` | No error thrown |
| `@clean After hook clears browser context` | Verify clearContext called |
| `@clean After hook handles missing browser gracefully` | No browser, no error |
| `@fresh-scan Before hook creates new security session` | Verify newSession called |
| `@fresh-scan Before hook handles missing security gracefully` | No security adapter, no error |

### 4.4 Variable Steps (`tests/interface/steps/variables.steps.test.ts`) -- NEW

**Mocking strategy**: Create a mock `TestWorld` instance with real `VariableService` and `InterpolationService`, then call step handler functions directly.

| Test | Description |
|------|-------------|
| `'I set variable {string} to {string}'` stores string | Verify variable stored |
| `'I set variable {string} to {string}'` interpolates value | `${existing_var}` resolved |
| `'I set variable {string} to {int}'` stores number | Verify numeric storage |
| `'I set variable {string} to:' with JSON` | Doc string parsed as JSON |
| `'I set variable {string} to:' with plain text` | Non-JSON stored as string |
| `'the variable {string} should equal {string}'` passes | Matching value |
| `'the variable {string} should equal {string}'` fails | Non-matching value throws |
| `'the variable {string} should equal {int}'` passes | Matching number |
| `'the variable {string} should exist'` passes | Variable is set |
| `'the variable {string} should not exist'` passes | Variable not set |
| `'the variable {string} should contain {string}'` passes | Substring match |
| `'the variable {string} should match {string}'` passes | Regex match |
| `'the variable {string} should match {string}'` fails | Regex mismatch throws |

### 4.5 HTTP Steps (`tests/interface/steps/http-steps.test.ts`) -- NEW

**Mocking strategy**: Mock `HttpPort` with a stub that captures method calls and returns configurable responses.

#### Request Building Steps

| Test | Description |
|------|-------------|
| `'I set header {string} to {string}'` calls http.setHeader | Verify delegation |
| `'I set header {string} to {string}'` interpolates value | Variable in header value |
| `'I set the following headers:' sets multiple` | DataTable with multiple rows |
| `'I set bearer token to {string}'` calls http.setBearerToken | Verify delegation |
| `'I set bearer token to {string}'` interpolates token | Variable in token |
| `'I set basic auth with username {string} and password {string}'` | Verify delegation |
| `'I set query param {string} to {string}'` calls http.setQueryParam | Verify delegation |
| `'I set the following query params:' sets multiple` | DataTable with multiple rows |

#### HTTP Method Steps

| Test | Description |
|------|-------------|
| `'I GET {string}'` calls http.get with interpolated path | Verify path and interpolation |
| `'I POST to {string}'` calls http.post without body | Verify no body |
| `'I POST to {string} with body:'` calls http.post with parsed JSON | Verify JSON parsing |
| `'I POST to {string} with body:'` interpolates body variables | `${var}` in JSON body |
| `'I PUT to {string} with body:'` calls http.put with parsed JSON | Verify delegation |
| `'I PATCH to {string} with body:'` calls http.patch with parsed JSON | Verify delegation |
| `'I DELETE {string}'` calls http.delete | Verify delegation |

#### Response Assertion Steps

| Test | Description |
|------|-------------|
| `'the response status should be {int}'` passes for matching status | 200 === 200 |
| `'the response status should be {int}'` fails for mismatched status | 200 !== 404 |
| `'the response status should not be {int}'` passes for different | 200 !== 500 |
| `'the response body path {string} should equal {string}'` passes | JSONPath match |
| `'the response body path {string} should equal {int}'` passes | Numeric JSONPath |
| `'the response body path {string} should exist'` passes | Defined path |
| `'the response body path {string} should not exist'` passes | Undefined path |
| `'the response body path {string} should contain {string}'` passes | Substring in path value |
| `'the response body path {string} should match {string}'` passes | Regex match on path |
| `'the response body path {string} should have {int} items'` passes | Array length check |
| `'the response body should be valid JSON'` passes | Body is object |
| `'the response header {string} should equal {string}'` passes | Header match |
| `'the response header {string} should contain {string}'` passes | Header substring |
| `'the response time should be less than {int} ms'` passes | Below threshold |
| `'the response time should be less than {int} ms'` fails | Above threshold |
| `'I store response body path {string} as {string}'` stores | Variable set from JSONPath |
| `'I store response header {string} as {string}'` stores | Variable set from header |
| `'I store response status as {string}'` stores | Variable set from status |

### 4.6 Browser Steps (`tests/interface/steps/browser-steps.test.ts`) -- NEW

**Mocking strategy**: Mock `BrowserPort` with stubs that capture calls and return configurable values.

#### Navigation Steps

| Test | Description |
|------|-------------|
| `'I navigate to {string}'` calls browser.goto | Verify path interpolation |
| `'I am on {string}'` calls browser.goto (alias) | Same behavior as navigate |
| `'I reload the page'` calls browser.reload | Verify delegation |
| `'I go back'` calls browser.goBack | Verify delegation |
| `'I wait for navigation'` calls browser.waitForNavigation | Verify delegation |

#### Interaction Steps

| Test | Description |
|------|-------------|
| `'I click on {string}'` calls browser.click | Verify selector interpolation |
| `'I fill {string} with {string}'` calls browser.fill | Verify selector and value |
| `'I select {string} from {string}'` calls browser.selectOption | Verify value and selector order |
| `'I check {string}'` calls browser.check | Verify selector |
| `'I wait for {string}'` calls browser.waitForSelector | Default options |
| `'I wait for {string} to be visible'` passes state:visible | Verify options |
| `'I wait for {string} to be hidden'` passes state:hidden | Verify options |
| `'I take a screenshot'` calls browser.screenshot and attach | Verify Buffer + MIME type |

#### Assertion Steps

| Test | Description |
|------|-------------|
| `'the URL should be {string}'` passes for exact match | Verify url() comparison |
| `'the URL should contain {string}'` passes for substring | Verify toContain |
| `'the page title should be {string}'` passes for exact match | Verify title() |
| `'the page title should contain {string}'` passes for substring | Verify title() substring |
| `'I should see {string}'` passes when visible | isVisible returns true |
| `'I should see {string}'` fails when not visible | isVisible returns false |
| `'I should not see {string}'` passes when not visible | isVisible returns false |
| `'the element {string} should contain text {string}'` passes | textContent contains |
| `'the element {string} should have text {string}'` passes (trimmed) | textContent exact match |
| `'the element {string} should be visible'` passes | isVisible true |
| `'the element {string} should not be visible'` passes | isVisible false |
| `'I store text of {string} as {string}'` stores text content | Verify variable stored |
| `'I store the URL as {string}'` stores current URL | Verify variable stored |

### 4.7 CLI Steps (`tests/interface/steps/cli-steps.test.ts`) -- NEW

**Mocking strategy**: Mock `CliPort` with stubs that capture calls and return configurable `CommandResult` objects.

#### Environment Steps

| Test | Description |
|------|-------------|
| `'I set env {string} to {string}'` calls cli.setEnv | Verify name and interpolated value |
| `'I set the following environment variables:'` sets multiple | DataTable with multiple rows |
| `'I set working directory to {string}'` calls cli.setWorkingDir | Verify interpolated path |

#### Execution Steps

| Test | Description |
|------|-------------|
| `'I run {string}'` calls cli.run with interpolated command | Verify command string |
| `'I run {string} with stdin:' (docstring)` calls cli.runWithStdin | Verify command and stdin |
| `'I run {string} with stdin {string}' (inline)` calls cli.runWithStdin | Verify inline stdin |

#### Assertion Steps

| Test | Description |
|------|-------------|
| `'the exit code should be {int}'` passes for matching | exitCode === 0 |
| `'the exit code should be {int}'` fails for mismatched | exitCode !== expected |
| `'the exit code should not be {int}'` passes for different | exitCode !== unexpected |
| `'the command should succeed'` passes for exit code 0 | exitCode === 0 |
| `'the command should fail'` passes for non-zero exit code | exitCode !== 0 |
| `'stdout should contain {string}'` passes for substring | stdout.includes(expected) |
| `'stdout should not contain {string}'` passes | stdout does not include |
| `'stdout should match {string}'` passes for regex match | Regex test on stdout |
| `'stderr should contain {string}'` passes for substring | stderr.includes(expected) |
| `'stderr should not contain {string}'` passes | stderr does not include |
| `'stderr should be empty'` passes when stderr is blank | Empty/whitespace only |
| `'stdout should equal:' (docstring)` passes for exact match | Trimmed comparison |
| `'I store stdout as {string}'` stores trimmed stdout | Verify variable |
| `'I store stderr as {string}'` stores trimmed stderr | Verify variable |
| `'I store exit code as {string}'` stores exit code number | Verify variable |

### 4.8 Graph Steps (`tests/interface/steps/graph-steps.test.ts`) -- NEW

**Mocking strategy**: Mock `GraphPort` with stubs returning configurable nodes, dependencies, and cycles.

#### Selection Steps

| Test | Description |
|------|-------------|
| `'I query nodes in layer {string}'` calls graph.getNodesInLayer | Verify layer param |
| `'I query nodes in layer {string}'` stores results as _lastNodes | Verify variable storage |
| `'I query {string} nodes in layer {string}'` filters by type | Verify type param (e.g., 'class') |
| `'I query classes implementing {string}'` calls graph.getClassesImplementing | Verify interface name |
| `'I execute Cypher query:' (docstring)` calls graph.query | Verify Cypher string |
| `'I execute Cypher query {string}' (inline)` calls graph.query | Verify inline Cypher |

#### Dependency Assertion Steps

| Test | Description |
|------|-------------|
| `'layer {string} should not depend on layer {string}'` passes when empty | No dependencies |
| `'layer {string} should not depend on layer {string}'` fails when deps exist | Has dependencies |
| `'layer {string} should depend on layer {string}'` passes when deps exist | Has dependencies |
| `'layer {string} should depend on layer {string}'` fails when empty | No dependencies |
| `'there should be no circular dependencies'` passes when none | Empty cycles |
| `'there should be no circular dependencies'` fails when found | Cycles detected |
| `'there should be at most {int} circular dependencies'` passes | Within limit |
| `'there should be at most {int} circular dependencies'` fails | Exceeds limit |

#### Query Assertion Steps

| Test | Description |
|------|-------------|
| `'the node count should be {int}'` passes for matching count | Array length match |
| `'the node count should be greater than {int}'` passes | Greater than |
| `'a node named {string} should exist'` passes when found | Name lookup |
| `'a node named {string} should not exist'` passes when absent | Name lookup |
| `'the query result count should be {int}'` passes for matching | Result array length |
| `'I store node count as {string}'` stores count | Verify variable |

### 4.9 Security Steps (`tests/interface/steps/security-steps.test.ts`) -- NEW

**Mocking strategy**: Mock `SecurityPort` with stubs returning configurable alerts, scan results, and check results.

#### Scanning Steps

| Test | Description |
|------|-------------|
| `'I start a new security session'` calls security.newSession | Verify delegation |
| `'I spider {string}'` calls security.spider | Verify URL interpolation |
| `'I spider {string}'` stores result as _spiderResult | Verify variable |
| `'I run an active scan on {string}'` calls security.activeScan | Verify URL |
| `'I run an active scan on {string}'` stores result as _scanResult | Verify variable |
| `'I run a passive scan on {string}'` calls security.passiveScan | Verify URL |
| `'I check security headers on {string}'` calls checkSecurityHeaders | Verify URL |
| `'I check SSL certificate on {string}'` calls checkSslCertificate | Verify URL |
| `'I generate security report to {string}'` calls generateHtmlReport | Verify path |

#### Assertion Steps

| Test | Description |
|------|-------------|
| `'there should be no {string} risk alerts'` passes when none | getAlertsByRisk returns [] |
| `'there should be no {string} risk alerts'` fails when found | getAlertsByRisk returns alerts |
| `'there should be no alerts with risk at least {string}'` passes | No alerts above threshold |
| `'there should be no alerts with risk at least {string}'` fails | Alerts above threshold |
| `'the total alert count should be less than {int}'` passes | Below max |
| `'the {string} risk alert count should be {int}'` passes | Exact match |
| `'the {string} risk alert count should be less than {int}'` passes | Below max |
| `'the security header {string} should be present'` passes | Header marked present |
| `'the security header {string} should not be present'` passes | Header marked absent |
| `'all required security headers should be present'` passes | No missing headers |
| `'the SSL certificate should be valid'` passes | valid === true |
| `'the SSL certificate should have no errors'` passes | Empty errors array |
| `'the spider should have found at least {int} URLs'` passes | urlsFound >= min |
| `'I store alert count as {string}'` stores count | Verify variable |

---

## Phase 5: Public API Tests

### 5.1 Public API Exports (`tests/public-api.test.ts`) -- NEW

| Test | Description |
|------|-------------|
| `exports defineConfig function` | `typeof defineConfig === 'function'` |
| `exports loadConfig function` | `typeof loadConfig === 'function'` |
| `exports createAdapters function` | `typeof createAdapters === 'function'` |
| `exports TestWorld class` | `typeof TestWorld === 'function'` |
| `exports RiskLevel value object` | Verify `RiskLevel.High` etc. |
| `exports NodeType type` | Compile-time type check |
| `exports DomainError class` | `typeof DomainError === 'function'` |
| `exports VariableNotFoundError class` | `typeof VariableNotFoundError === 'function'` |
| `exports AdapterNotConfiguredError class` | `typeof AdapterNotConfiguredError === 'function'` |
| `exports VariableService class` | `typeof VariableService === 'function'` |
| `exports InterpolationService class` | `typeof InterpolationService === 'function'` |
| `does not export internal infrastructure adapters` | PlaywrightHttpAdapter not in exports |
| `does not export internal factories directly` | Only through createAdapters |
| `type exports are importable` | HttpPort, BrowserPort, CliPort, GraphPort, SecurityPort, Adapters, ExoBddConfig |

---

## Summary

| Phase | Test File | New Tests | Existing Tests | Total |
|-------|-----------|-----------|----------------|-------|
| 1 | domain/value-objects.test.ts | 6 | 9 | 15 |
| 1 | domain/errors.test.ts | 4 | 6 | 10 |
| 1 | domain/entities.test.ts | 12 | 0 | 12 |
| 2 | application/services.test.ts | 13 | 14 | 27 |
| 2 | application/config-loader.test.ts | 6 | 0 | 6 |
| 2 | application/config-schema.test.ts | 10 | 0 | 10 |
| 3 | infrastructure/http-adapter.test.ts | 25 | 0 | 25 |
| 3 | infrastructure/browser-adapter.test.ts | 19 | 0 | 19 |
| 3 | infrastructure/cli-adapter.test.ts | 12 | 9 | 21 |
| 3 | infrastructure/graph-adapter.test.ts | 15 | 0 | 15 |
| 3 | infrastructure/security-adapter.test.ts | 21 | 0 | 21 |
| 3 | infrastructure/adapter-factory.test.ts | 13 | 0 | 13 |
| 4 | interface/world.test.ts | 10 | 0 | 10 |
| 4 | interface/hooks/lifecycle.test.ts | 11 | 0 | 11 |
| 4 | interface/hooks/tagged.test.ts | 14 | 0 | 14 |
| 4 | interface/steps/variables.steps.test.ts | 13 | 0 | 13 |
| 4 | interface/steps/http-steps.test.ts | 33 | 0 | 33 |
| 4 | interface/steps/browser-steps.test.ts | 26 | 0 | 26 |
| 4 | interface/steps/cli-steps.test.ts | 21 | 0 | 21 |
| 4 | interface/steps/graph-steps.test.ts | 20 | 0 | 20 |
| 4 | interface/steps/security-steps.test.ts | 23 | 0 | 23 |
| 5 | public-api.test.ts | 14 | 0 | 14 |
| **Total** | **22 files** | **301** | **38** | **339** |

---

## Mocking Strategy Summary

| Layer | What to Mock | Library/Approach |
|-------|-------------|-----------------|
| Infrastructure: HTTP | `@playwright/test` request module | `bun:test` mock/spyOn on module |
| Infrastructure: Browser | `playwright` chromium.launch | `bun:test` mock/spyOn on module |
| Infrastructure: Graph | `neo4j-driver` driver/session | `bun:test` mock/spyOn on module |
| Infrastructure: Security | `global.fetch` | `bun:test` mock/spyOn on globalThis.fetch |
| Infrastructure: Factory | All adapter constructors | `bun:test` mock on adapter modules |
| Interface: Steps | Port interfaces (HttpPort, etc.) | Hand-crafted stub objects implementing port interfaces |
| Interface: Hooks | Cucumber hook functions + adapters | Mock `@cucumber/cucumber` registration functions |

---

## Running Tests

```bash
# Run all tests
bun test

# Run tests for a specific phase
bun test tests/domain/
bun test tests/application/
bun test tests/infrastructure/
bun test tests/interface/

# Run a single test file
bun test tests/infrastructure/http-adapter.test.ts

# Run tests matching a pattern
bun test --grep "HttpAdapter"
```
