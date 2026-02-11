import { test, expect, describe, beforeEach, mock, jest } from 'bun:test'

// --- Mock state ---
let capturedFetchArgs: { url: string; options: Record<string, unknown> }[] = []
let mockResponseStatus = 200
let mockResponseStatusText = 'OK'
let mockResponseHeaders: { name: string; value: string }[] = [
  { name: 'content-type', value: 'application/json' },
]
let mockResponseBody = '{"message":"ok"}'
let mockDisposeCalled = false

const mockContext = {
  fetch: mock(async (url: string, options: Record<string, unknown>) => {
    capturedFetchArgs.push({ url, options })
    return {
      status: () => mockResponseStatus,
      statusText: () => mockResponseStatusText,
      headersArray: () => mockResponseHeaders,
      text: async () => mockResponseBody,
    }
  }),
  dispose: mock(async () => {
    mockDisposeCalled = true
  }),
}

const mockNewContext = mock(async (_opts: Record<string, unknown>) => mockContext)

mock.module('@playwright/test', () => ({
  request: {
    newContext: mockNewContext,
  },
  chromium: {
    launch: mock(() => Promise.resolve({})),
  },
  default: {},
}))

// Canned-values lookup map for JSONPath mock — each test uses a unique path,
// so we key by path string and return the expected query results directly.
const jsonPathCannedValues: Record<string, unknown[]> = {
  '$.name': ['Alice'],
  '$.nonexistent': [],
  '$.data.users[0].name': ['Bob'],
  '$.items[*].id': [1, 2, 3],
}

mock.module('jsonpath', () => ({
  default: {
    query: (_obj: unknown, path: string) => jsonPathCannedValues[path] ?? [],
  },
}))

// Import after mocking
const { PlaywrightHttpAdapter } = await import(
  '../../src/infrastructure/adapters/http/PlaywrightHttpAdapter.ts'
)

const defaultConfig = {
  baseURL: 'https://api.example.com',
  timeout: 5000,
  headers: { 'X-Custom': 'value' },
}

function createAdapter(configOverrides?: Partial<typeof defaultConfig>) {
  return new PlaywrightHttpAdapter({ ...defaultConfig, ...configOverrides })
}

describe('PlaywrightHttpAdapter', () => {
  beforeEach(() => {
    capturedFetchArgs = []
    mockResponseStatus = 200
    mockResponseStatusText = 'OK'
    mockResponseHeaders = [{ name: 'content-type', value: 'application/json' }]
    mockResponseBody = '{"message":"ok"}'
    mockDisposeCalled = false
    mockNewContext.mockClear()
    mockContext.fetch.mockClear()
    mockContext.dispose.mockClear()
  })

  // 1
  test('initialize creates API context with config', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    expect(mockNewContext).toHaveBeenCalledTimes(1)
    const call = mockNewContext.mock.calls[0]
    expect(call).toBeDefined()
    const args = call![0] as Record<string, unknown>
    expect(args.baseURL).toBe('https://api.example.com')
    expect(args.timeout).toBe(5000)
    expect(args.extraHTTPHeaders).toEqual({ 'X-Custom': 'value' })
  })

  // 2
  test('setHeader stores pending header', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    adapter.setHeader('X-Request-Id', '123')
    await adapter.get('/test')

    expect(capturedFetchArgs).toHaveLength(1)
    const fetchOpts = capturedFetchArgs[0]!.options
    expect(fetchOpts.headers).toEqual({ 'X-Request-Id': '123' })
  })

  // 3
  test('setHeaders stores multiple headers', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    adapter.setHeaders({ 'X-A': '1', 'X-B': '2' })
    await adapter.get('/test')

    expect(capturedFetchArgs).toHaveLength(1)
    const fetchOpts = capturedFetchArgs[0]!.options
    expect(fetchOpts.headers).toEqual({ 'X-A': '1', 'X-B': '2' })
  })

  // 4
  test('setQueryParam appends to URL', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    adapter.setQueryParam('page', '1')
    await adapter.get('/items')

    expect(capturedFetchArgs).toHaveLength(1)
    const url = capturedFetchArgs[0]!.url
    expect(url).toContain('page=1')
  })

  // 5
  test('setQueryParams appends multiple params', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    adapter.setQueryParams({ page: '2', limit: '10' })
    await adapter.get('/items')

    expect(capturedFetchArgs).toHaveLength(1)
    const url = capturedFetchArgs[0]!.url
    expect(url).toContain('page=2')
    expect(url).toContain('limit=10')
  })

  // 6
  test('setBearerToken sets Authorization header', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    adapter.setBearerToken('my-token')
    await adapter.get('/secure')

    expect(capturedFetchArgs).toHaveLength(1)
    const headers = capturedFetchArgs[0]!.options.headers as Record<string, string>
    expect(headers['Authorization']).toBe('Bearer my-token')
  })

  // 7
  test('setBasicAuth sets Authorization header', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    adapter.setBasicAuth('user', 'pass')
    await adapter.get('/secure')

    const expected = `Basic ${btoa('user:pass')}`
    expect(capturedFetchArgs).toHaveLength(1)
    const headers = capturedFetchArgs[0]!.options.headers as Record<string, string>
    expect(headers['Authorization']).toBe(expected)
  })

  // 8
  test('get sends GET request to correct URL', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    await adapter.get('/users')

    expect(capturedFetchArgs).toHaveLength(1)
    expect(capturedFetchArgs[0]!.url).toBe('https://api.example.com/users')
    expect(capturedFetchArgs[0]!.options.method).toBe('GET')
  })

  // 9
  test('post sends POST with body', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    const body = { name: 'test' }
    await adapter.post('/users', body)

    expect(capturedFetchArgs).toHaveLength(1)
    expect(capturedFetchArgs[0]!.options.method).toBe('POST')
    expect(capturedFetchArgs[0]!.options.data).toEqual(body)
    expect(capturedFetchArgs[0]!.url).toBe('https://api.example.com/users')
  })

  // 10
  test('put sends PUT with body', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    const body = { name: 'updated' }
    await adapter.put('/users/1', body)

    expect(capturedFetchArgs).toHaveLength(1)
    expect(capturedFetchArgs[0]!.options.method).toBe('PUT')
    expect(capturedFetchArgs[0]!.options.data).toEqual(body)
    expect(capturedFetchArgs[0]!.url).toBe('https://api.example.com/users/1')
  })

  // 11
  test('patch sends PATCH with body', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    const body = { active: false }
    await adapter.patch('/users/1', body)

    expect(capturedFetchArgs).toHaveLength(1)
    expect(capturedFetchArgs[0]!.options.method).toBe('PATCH')
    expect(capturedFetchArgs[0]!.options.data).toEqual(body)
    expect(capturedFetchArgs[0]!.url).toBe('https://api.example.com/users/1')
  })

  // 12
  test('delete sends DELETE request', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    await adapter.delete('/users/1')

    expect(capturedFetchArgs).toHaveLength(1)
    expect(capturedFetchArgs[0]!.options.method).toBe('DELETE')
    expect(capturedFetchArgs[0]!.url).toBe('https://api.example.com/users/1')
  })

  // 13
  test('response exposes status code', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    mockResponseStatus = 201
    await adapter.get('/test')

    expect(adapter.status).toBe(201)
  })

  // 14
  test('response exposes parsed JSON body', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    mockResponseBody = '{"id":1,"name":"Alice"}'
    await adapter.get('/users/1')

    expect(adapter.body).toEqual({ id: 1, name: 'Alice' })
  })

  // 15
  test('response exposes raw text', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    mockResponseBody = '{"id":1}'
    await adapter.get('/test')

    expect(adapter.text).toBe('{"id":1}')
  })

  // 16
  test('response exposes headers', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    mockResponseHeaders = [
      { name: 'content-type', value: 'application/json' },
      { name: 'x-request-id', value: 'abc-123' },
    ]
    await adapter.get('/test')

    expect(adapter.headers).toEqual({
      'content-type': 'application/json',
      'x-request-id': 'abc-123',
    })
  })

  // 17
  test('response captures response time', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    await adapter.get('/test')

    expect(adapter.responseTime).toBeGreaterThanOrEqual(0)
  })

  // 18
  test('getBodyPath extracts value via JSONPath', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    mockResponseBody = '{"name":"Alice"}'
    await adapter.get('/test')

    expect(adapter.getBodyPath('$.name')).toBe('Alice')
  })

  // 19
  test('getBodyPath returns undefined for missing path', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    mockResponseBody = '{"name":"Alice"}'
    await adapter.get('/test')

    expect(adapter.getBodyPath('$.nonexistent')).toBeUndefined()
  })

  // 20
  test('getBodyPath handles nested paths', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    mockResponseBody = '{"data":{"users":[{"name":"Bob"}]}}'
    await adapter.get('/test')

    expect(adapter.getBodyPath('$.data.users[0].name')).toBe('Bob')
  })

  // 21
  test('getBodyPath handles array queries', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    mockResponseBody = '{"items":[{"id":1},{"id":2},{"id":3}]}'
    await adapter.get('/test')

    // JSONPath.query returns [1, 2, 3] for $.items[*].id
    // getBodyPath takes [0] of query results, returning the first match
    expect(adapter.getBodyPath('$.items[*].id')).toBe(1)
  })

  // 22
  test('pending headers/params reset after request', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    adapter.setHeader('X-First', 'yes')
    adapter.setQueryParam('token', 'abc')
    await adapter.get('/first')

    await adapter.get('/second')

    // Second request should have empty headers and no query params
    expect(capturedFetchArgs).toHaveLength(2)
    const secondFetch = capturedFetchArgs[1]!
    expect(secondFetch.options.headers).toEqual({})
    expect(secondFetch.url).toBe('https://api.example.com/second')
    expect(secondFetch.url).not.toContain('token=')
  })

  // 23
  test('parseBody handles non-JSON response', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    mockResponseBody = 'plain text response'
    await adapter.get('/text')

    expect(adapter.body).toBe('plain text response')
    expect(adapter.text).toBe('plain text response')
  })

  // 24
  test('buildUrl resolves relative paths against baseURL', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    adapter.setQueryParam('q', 'search')
    await adapter.get('/api/v1/search')

    expect(capturedFetchArgs).toHaveLength(1)
    const url = capturedFetchArgs[0]!.url
    expect(url).toBe('https://api.example.com/api/v1/search?q=search')
  })

  // 25
  test('dispose calls context.dispose()', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    await adapter.dispose()

    expect(mockDisposeCalled).toBe(true)
    expect(mockContext.dispose).toHaveBeenCalledTimes(1)
  })

  // 26
  test('context.fetch() throwing propagates network error', async () => {
    const adapter = createAdapter()
    await adapter.initialize()

    mockContext.fetch.mockImplementationOnce(() => {
      throw new Error('net::ERR_CONNECTION_REFUSED')
    })

    await expect(adapter.get('/unreachable')).rejects.toThrow('net::ERR_CONNECTION_REFUSED')
  })

  // 27
  test('calling methods before initialize() throws', async () => {
    const adapter = createAdapter()
    // Do NOT call adapter.initialize()

    await expect(adapter.get('/test')).rejects.toThrow()
  })

  // 28
  test('timeout config is forwarded to API context', async () => {
    const adapter = createAdapter({ timeout: 500 })
    await adapter.initialize()

    expect(mockNewContext).toHaveBeenCalledTimes(1)
    const call = mockNewContext.mock.calls[0]
    const args = call![0] as Record<string, unknown>
    expect(args.timeout).toBe(500)
  })
})
