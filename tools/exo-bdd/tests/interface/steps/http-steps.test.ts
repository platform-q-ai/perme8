import { test, expect, describe, beforeEach, mock } from 'bun:test'
import { VariableService } from '../../../src/application/services/VariableService.ts'
import { InterpolationService } from '../../../src/application/services/InterpolationService.ts'
import type { HttpResponse } from '../../../src/domain/entities/HttpResponse.ts'

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

// Mock @playwright/test so the response-assertions handlers use a working expect
mock.module('@playwright/test', () => ({
  expect,
  default: {},
}))

// Dynamic imports after mocks so Cucumber registrations run harmlessly
const { setHeader, setHeaders, setBearerToken, setBasicAuth, setQueryParam, setQueryParams } = await import('../../../src/interface/steps/http/request-building.steps.ts')
const { httpGet, httpPost, httpPostWithBody, httpPostWithRawBody, httpPutWithBody, httpPatchWithBody, httpDelete } = await import('../../../src/interface/steps/http/http-methods.steps.ts')
const { assertStatusIs, assertBodyPathEqualsString, assertBodyPathEqualsInt, assertBodyPathExists, assertBodyPathNotExists, assertBodyPathContains, assertBodyPathMatches, assertBodyPathHasItems, assertBodyIsValidJson, assertHeaderEquals, assertHeaderContains, assertResponseTimeLessThan, storeBodyPath, storeHeader, storeStatus } = await import('../../../src/interface/steps/http/response-assertions.steps.ts')

/**
 * Tests for HTTP step definition logic (request-building, http-methods, response-assertions).
 *
 * Each test invokes the actual exported handler functions from the step
 * definition files, passing in mock world objects that satisfy the context
 * interfaces.
 */

interface MockHttpPort {
  setHeader: ReturnType<typeof mock>
  setHeaders: ReturnType<typeof mock>
  setQueryParam: ReturnType<typeof mock>
  setQueryParams: ReturnType<typeof mock>
  setBearerToken: ReturnType<typeof mock>
  setBasicAuth: ReturnType<typeof mock>
  get: ReturnType<typeof mock>
  post: ReturnType<typeof mock>
  put: ReturnType<typeof mock>
  patch: ReturnType<typeof mock>
  delete: ReturnType<typeof mock>
  request: ReturnType<typeof mock>
  getBodyPath: ReturnType<typeof mock>
  status: number
  statusText: string
  headers: Record<string, string>
  body: unknown
  text: string
  responseTime: number
  response: HttpResponse
  config: { baseUrl: string }
  dispose: ReturnType<typeof mock>
}

interface MockWorld {
  http: MockHttpPort
  setVariable(name: string, value: unknown): void
  getVariable(name: string): unknown
  hasVariable(name: string): boolean
  interpolate(text: string): string
}

function createMockHttpPort(overrides: Partial<MockHttpPort> = {}): MockHttpPort {
  const defaultResponse: HttpResponse = {
    status: 200,
    statusText: 'OK',
    headers: { 'content-type': 'application/json' },
    body: {},
    text: '{}',
    responseTime: 50,
  }

  return {
    setHeader: mock(() => {}),
    setHeaders: mock(() => {}),
    setQueryParam: mock(() => {}),
    setQueryParams: mock(() => {}),
    setBearerToken: mock(() => {}),
    setBasicAuth: mock(() => {}),
    get: mock(async () => {}),
    post: mock(async () => {}),
    put: mock(async () => {}),
    patch: mock(async () => {}),
    delete: mock(async () => {}),
    request: mock(async () => {}),
    getBodyPath: mock(() => undefined),
    status: 200,
    statusText: 'OK',
    headers: { 'content-type': 'application/json' },
    body: {},
    text: '{}',
    responseTime: 50,
    response: defaultResponse,
    config: { baseUrl: 'http://localhost:3000' },
    dispose: mock(async () => {}),
    ...overrides,
  }
}

function createMockWorld(httpOverrides: Partial<MockHttpPort> = {}): MockWorld {
  const variableService = new VariableService()
  const interpolationService = new InterpolationService(variableService)
  return {
    http: createMockHttpPort(httpOverrides),
    setVariable: (name, value) => variableService.set(name, value),
    getVariable: (name) => variableService.get(name),
    hasVariable: (name) => variableService.has(name),
    interpolate: (text) => interpolationService.interpolate(text),
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Request Building Steps (request-building.steps.ts)
// ═════════════════════════════════════════════════════════════════════════════

describe('Request Building Steps', () => {
  let world: MockWorld

  beforeEach(() => {
    world = createMockWorld()
  })

  // ─── I set header {string} to {string} ─────────────────────────────────

  describe('I set header {string} to {string}', () => {
    test('calls http.setHeader with name and value', () => {
      setHeader(world, 'Content-Type', 'application/json')

      expect(world.http.setHeader).toHaveBeenCalledWith('Content-Type', 'application/json')
    })

    test('interpolates the header value', () => {
      world.setVariable('token', 'abc123')

      setHeader(world, 'X-Custom', 'Bearer ${token}')

      expect(world.http.setHeader).toHaveBeenCalledWith('X-Custom', 'Bearer abc123')
    })
  })

  // ─── I set the following headers: ──────────────────────────────────────

  describe('I set the following headers:', () => {
    test('sets multiple headers from data table', () => {
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        Accept: 'text/html',
        'X-Request-Id': '12345',
      }

      setHeaders(world, headers)

      expect(world.http.setHeader).toHaveBeenCalledTimes(3)
      expect(world.http.setHeader).toHaveBeenCalledWith('Content-Type', 'application/json')
      expect(world.http.setHeader).toHaveBeenCalledWith('Accept', 'text/html')
      expect(world.http.setHeader).toHaveBeenCalledWith('X-Request-Id', '12345')
    })
  })

  // ─── I set bearer token to {string} ────────────────────────────────────

  describe('I set bearer token to {string}', () => {
    test('calls http.setBearerToken', () => {
      setBearerToken(world, 'my-jwt-token')

      expect(world.http.setBearerToken).toHaveBeenCalledWith('my-jwt-token')
    })

    test('interpolates the token value', () => {
      world.setVariable('jwt', 'eyJhbGciOiJIUzI1NiJ9')

      setBearerToken(world, '${jwt}')

      expect(world.http.setBearerToken).toHaveBeenCalledWith('eyJhbGciOiJIUzI1NiJ9')
    })
  })

  // ─── I set basic auth with username {string} and password {string} ─────

  describe('I set basic auth with username {string} and password {string}', () => {
    test('calls http.setBasicAuth with interpolated credentials', () => {
      setBasicAuth(world, 'admin', 'secret')

      expect(world.http.setBasicAuth).toHaveBeenCalledWith('admin', 'secret')
    })
  })

  // ─── I set query param {string} to {string} ───────────────────────────

  describe('I set query param {string} to {string}', () => {
    test('calls http.setQueryParam', () => {
      setQueryParam(world, 'page', '1')

      expect(world.http.setQueryParam).toHaveBeenCalledWith('page', '1')
    })
  })

  // ─── I set the following query params: ─────────────────────────────────

  describe('I set the following query params:', () => {
    test('sets multiple query params from data table', () => {
      const params: Record<string, string> = {
        page: '1',
        limit: '10',
        sort: 'name',
      }

      setQueryParams(world, params)

      expect(world.http.setQueryParam).toHaveBeenCalledTimes(3)
      expect(world.http.setQueryParam).toHaveBeenCalledWith('page', '1')
      expect(world.http.setQueryParam).toHaveBeenCalledWith('limit', '10')
      expect(world.http.setQueryParam).toHaveBeenCalledWith('sort', 'name')
    })
  })
})

// ═════════════════════════════════════════════════════════════════════════════
// HTTP Method Steps (http-methods.steps.ts)
// ═════════════════════════════════════════════════════════════════════════════

describe('HTTP Method Steps', () => {
  let world: MockWorld

  beforeEach(() => {
    world = createMockWorld()
  })

  // ─── I GET {string} ────────────────────────────────────────────────────

  describe('I GET {string}', () => {
    test('calls http.get with interpolated path', async () => {
      await httpGet(world, '/api/users')

      expect(world.http.get).toHaveBeenCalledWith('/api/users')
    })
  })

  // ─── I POST to {string} ───────────────────────────────────────────────

  describe('I POST to {string}', () => {
    test('calls http.post without body', async () => {
      await httpPost(world, '/api/users')

      expect(world.http.post).toHaveBeenCalledWith('/api/users')
    })
  })

  // ─── I POST to {string} with body: ────────────────────────────────────

  describe('I POST to {string} with body:', () => {
    test('calls http.post with parsed JSON body', async () => {
      await httpPostWithBody(world, '/api/users', '{"name": "John", "age": 30}')

      expect(world.http.post).toHaveBeenCalledWith('/api/users', { name: 'John', age: 30 })
    })

    test('interpolates variables in the body', async () => {
      world.setVariable('userName', 'Alice')

      await httpPostWithBody(world, '/api/users', '{"name": "${userName}"}')

      expect(world.http.post).toHaveBeenCalledWith('/api/users', { name: 'Alice' })
    })
  })

  // ─── I POST raw to {string} with body: ───────────────────────────────

  describe('I POST raw to {string} with body:', () => {
    test('calls http.post with raw Buffer body (no JSON parsing)', async () => {
      await httpPostWithRawBody(world, '/api/users', '{this is not valid json}')

      expect(world.http.setHeader).toHaveBeenCalledWith('Content-Type', 'application/json')
      const call = (world.http.post as any).mock.calls[0]
      expect(call[0]).toBe('/api/users')
      expect(Buffer.isBuffer(call[1])).toBe(true)
      expect(call[1].toString('utf-8')).toBe('{this is not valid json}')
    })

    test('interpolates variables in the raw body', async () => {
      world.setVariable('wsId', 'abc-123')

      await httpPostWithRawBody(world, '/api/workspaces/${wsId}/data', '{invalid: "${wsId}"}')

      const call = (world.http.post as any).mock.calls[0]
      expect(call[0]).toBe('/api/workspaces/abc-123/data')
      expect(Buffer.isBuffer(call[1])).toBe(true)
      expect(call[1].toString('utf-8')).toBe('{invalid: "abc-123"}')
    })
  })

  // ─── I PUT to {string} with body: ─────────────────────────────────────

  describe('I PUT to {string} with body:', () => {
    test('calls http.put with parsed JSON body', async () => {
      await httpPutWithBody(world, '/api/users/1', '{"name": "Updated"}')

      expect(world.http.put).toHaveBeenCalledWith('/api/users/1', { name: 'Updated' })
    })
  })

  // ─── I PATCH to {string} with body: ───────────────────────────────────

  describe('I PATCH to {string} with body:', () => {
    test('calls http.patch with parsed JSON body', async () => {
      await httpPatchWithBody(world, '/api/users/1', '{"status": "active"}')

      expect(world.http.patch).toHaveBeenCalledWith('/api/users/1', { status: 'active' })
    })
  })

  // ─── I DELETE {string} ─────────────────────────────────────────────────

  describe('I DELETE {string}', () => {
    test('calls http.delete with interpolated path', async () => {
      await httpDelete(world, '/api/users/1')

      expect(world.http.delete).toHaveBeenCalledWith('/api/users/1')
    })
  })
})

// ═════════════════════════════════════════════════════════════════════════════
// Response Assertion Steps (response-assertions.steps.ts)
// ═════════════════════════════════════════════════════════════════════════════

describe('Response Assertion Steps', () => {
  // ─── the response status should be {int} ───────────────────────────────

  describe('the response status should be {int}', () => {
    test('passes when status matches', () => {
      const world = createMockWorld({ status: 200 } as Partial<MockHttpPort>)

      assertStatusIs(world, 200)
    })

    test('fails when status does not match', () => {
      const world = createMockWorld({ status: 404 } as Partial<MockHttpPort>)

      expect(() => {
        assertStatusIs(world, 200)
      }).toThrow()
    })
  })

  // ─── the response status should not be {int} ──────────────────────────

  describe('the response status should not be {int}', () => {
    test('passes when status does not match unexpected', () => {
      const world = createMockWorld({ status: 200 } as Partial<MockHttpPort>)

      expect(world.http.status).not.toBe(404)
    })
  })

  // ─── the response body path {string} should equal {string} ────────────

  describe('the response body path {string} should equal {string}', () => {
    test('passes when body path matches string', () => {
      const world = createMockWorld({
        getBodyPath: mock((path: string) => {
          if (path === '$.name') return 'John'
          return undefined
        }),
      } as Partial<MockHttpPort>)

      assertBodyPathEqualsString(world, '$.name', 'John')
    })
  })

  // ─── the response body path {string} should equal {int} ───────────────

  describe('the response body path {string} should equal {int}', () => {
    test('passes when body path matches number', () => {
      const world = createMockWorld({
        getBodyPath: mock((path: string) => {
          if (path === '$.age') return 30
          return undefined
        }),
      } as Partial<MockHttpPort>)

      assertBodyPathEqualsInt(world, '$.age', 30)
    })
  })

  // ─── the response body path {string} should exist ─────────────────────

  describe('the response body path {string} should exist', () => {
    test('passes when body path returns a defined value', () => {
      const world = createMockWorld({
        getBodyPath: mock(() => 'some value'),
      } as Partial<MockHttpPort>)

      assertBodyPathExists(world, '$.data')
    })
  })

  // ─── the response body path {string} should not exist ─────────────────

  describe('the response body path {string} should not exist', () => {
    test('passes when body path returns undefined', () => {
      const world = createMockWorld({
        getBodyPath: mock(() => undefined),
      } as Partial<MockHttpPort>)

      assertBodyPathNotExists(world, '$.missing')
    })
  })

  // ─── the response body path {string} should contain {string} ──────────

  describe('the response body path {string} should contain {string}', () => {
    test('passes when body path value contains substring', () => {
      const world = createMockWorld({
        getBodyPath: mock(() => 'Hello World'),
      } as Partial<MockHttpPort>)

      assertBodyPathContains(world, '$.message', 'World')
    })
  })

  // ─── the response body path {string} should match {string} ────────────

  describe('the response body path {string} should match {string}', () => {
    test('passes when body path value matches regex', () => {
      const world = createMockWorld({
        getBodyPath: mock(() => 'user-12345'),
      } as Partial<MockHttpPort>)

      assertBodyPathMatches(world, '$.id', '^user-\\d+$')
    })
  })

  // ─── the response body path {string} should have {int} items ──────────

  describe('the response body path {string} should have {int} items', () => {
    test('passes when array has expected length', () => {
      const world = createMockWorld({
        getBodyPath: mock(() => ['a', 'b', 'c']),
      } as Partial<MockHttpPort>)

      assertBodyPathHasItems(world, '$.items', 3)
    })
  })

  // ─── the response body should be valid JSON ───────────────────────────

  describe('the response body should be valid JSON', () => {
    test('passes when body is an object', () => {
      const world = createMockWorld({
        body: { key: 'value' },
      } as Partial<MockHttpPort>)

      assertBodyIsValidJson(world)
    })
  })

  // ─── the response header {string} should equal {string} ───────────────

  describe('the response header {string} should equal {string}', () => {
    test('passes when header matches expected value', () => {
      const responseHeaders = { 'content-type': 'application/json', 'x-request-id': '123' }
      const world = createMockWorld({
        response: {
          status: 200,
          statusText: 'OK',
          headers: responseHeaders,
          body: {},
          text: '{}',
          responseTime: 50,
        },
      } as Partial<MockHttpPort>)

      assertHeaderEquals(world, 'X-Request-Id', '123')
    })
  })

  // ─── the response header {string} should contain {string} ─────────────

  describe('the response header {string} should contain {string}', () => {
    test('passes when header contains expected substring', () => {
      const responseHeaders = { 'content-type': 'application/json; charset=utf-8' }
      const world = createMockWorld({
        response: {
          status: 200,
          statusText: 'OK',
          headers: responseHeaders,
          body: {},
          text: '{}',
          responseTime: 50,
        },
      } as Partial<MockHttpPort>)

      assertHeaderContains(world, 'Content-Type', 'application/json')
    })
  })

  // ─── the response time should be less than {int} ms ───────────────────

  describe('the response time should be less than {int} ms', () => {
    test('passes when response time is under limit', () => {
      const world = createMockWorld({
        response: {
          status: 200,
          statusText: 'OK',
          headers: {},
          body: {},
          text: '{}',
          responseTime: 50,
        },
      } as Partial<MockHttpPort>)

      assertResponseTimeLessThan(world, 1000)
    })

    test('fails when response time exceeds limit', () => {
      const world = createMockWorld({
        response: {
          status: 200,
          statusText: 'OK',
          headers: {},
          body: {},
          text: '{}',
          responseTime: 2500,
        },
      } as Partial<MockHttpPort>)

      expect(() => {
        assertResponseTimeLessThan(world, 1000)
      }).toThrow()
    })
  })

  // ─── I store response body path {string} as {string} ──────────────────

  describe('I store response body path {string} as {string}', () => {
    test('stores body path value as variable', () => {
      const world = createMockWorld({
        getBodyPath: mock((path: string) => {
          if (path === '$.id') return 'user-42'
          return undefined
        }),
      } as Partial<MockHttpPort>)

      storeBodyPath(world, '$.id', 'userId')

      expect(world.getVariable('userId')).toBe('user-42')
    })
  })

  // ─── I store response header {string} as {string} ─────────────────────

  describe('I store response header {string} as {string}', () => {
    test('stores header value as variable', () => {
      const responseHeaders = { 'x-request-id': 'req-abc-123' }
      const world = createMockWorld({
        response: {
          status: 200,
          statusText: 'OK',
          headers: responseHeaders,
          body: {},
          text: '{}',
          responseTime: 50,
        },
      } as Partial<MockHttpPort>)

      storeHeader(world, 'X-Request-Id', 'requestId')

      expect(world.getVariable('requestId')).toBe('req-abc-123')
    })
  })

  // ─── I store response status as {string} ──────────────────────────────

  describe('I store response status as {string}', () => {
    test('stores status code as variable', () => {
      const world = createMockWorld({ status: 201 } as Partial<MockHttpPort>)

      storeStatus(world, 'statusCode')

      expect(world.getVariable('statusCode')).toBe(201)
    })
  })
})
