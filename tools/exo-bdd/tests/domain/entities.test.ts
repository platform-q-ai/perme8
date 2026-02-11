import { test, expect, describe } from 'bun:test'
import type { Variable } from '../../src/domain/entities/Variable.ts'
import type { HttpRequest } from '../../src/domain/entities/HttpRequest.ts'
import type { HttpResponse } from '../../src/domain/entities/HttpResponse.ts'
import type { CommandResult } from '../../src/domain/entities/CommandResult.ts'
import type {
  GraphNode,
  Dependency,
  Cycle,
} from '../../src/domain/entities/GraphNode.ts'
import type {
  SecurityAlert,
  ScanResult,
  SpiderResult,
  HeaderCheckResult,
  SslCheckResult,
} from '../../src/domain/entities/SecurityAlert.ts'

describe('Entity interface contracts', () => {
  test('HttpResponse satisfies the interface shape', () => {
    const response: HttpResponse = {
      status: 200,
      statusText: 'OK',
      headers: { 'content-type': 'application/json' },
      body: { id: 1 },
      text: '{"id":1}',
      responseTime: 42,
    }
    expect(response.status).toBe(200)
    expect(response.statusText).toBe('OK')
    expect(response.headers['content-type']).toBe('application/json')
    expect(response.body).toEqual({ id: 1 })
    expect(response.text).toBe('{"id":1}')
    expect(response.responseTime).toBe(42)
  })

  test('HttpRequest satisfies the interface shape', () => {
    const request: HttpRequest = {
      method: 'POST',
      url: 'https://api.example.com/users',
      headers: { Authorization: 'Bearer token123' },
      body: { name: 'Test' },
      queryParams: { page: '1' },
    }
    expect(request.method).toBe('POST')
    expect(request.url).toBe('https://api.example.com/users')
    expect(request.headers.Authorization).toBe('Bearer token123')
    expect(request.body).toEqual({ name: 'Test' })
    expect(request.queryParams?.page).toBe('1')
  })

  test('CommandResult satisfies the interface shape', () => {
    const result: CommandResult = {
      stdout: 'hello world',
      stderr: '',
      exitCode: 0,
      duration: 150,
    }
    expect(result.stdout).toBe('hello world')
    expect(result.stderr).toBe('')
    expect(result.exitCode).toBe(0)
    expect(result.duration).toBe(150)
  })

  test('GraphNode satisfies the interface shape', () => {
    const node: GraphNode = {
      name: 'UserService',
      fqn: 'src.services.UserService',
      type: 'class',
      layer: 'application',
      file: 'src/services/UserService.ts',
    }
    expect(node.name).toBe('UserService')
    expect(node.fqn).toBe('src.services.UserService')
    expect(node.type).toBe('class')
    expect(node.layer).toBe('application')
    expect(node.file).toBe('src/services/UserService.ts')
  })

  test('Dependency satisfies the interface shape', () => {
    const from: GraphNode = { name: 'A', fqn: 'src.A', type: 'class' }
    const to: GraphNode = { name: 'B', fqn: 'src.B', type: 'interface' }
    const dep: Dependency = { from, to, type: 'implements' }
    expect(dep.from.name).toBe('A')
    expect(dep.to.name).toBe('B')
    expect(dep.type).toBe('implements')
  })

  test('Cycle satisfies the interface shape', () => {
    const nodeA: GraphNode = { name: 'A', fqn: 'src.A', type: 'class' }
    const nodeB: GraphNode = { name: 'B', fqn: 'src.B', type: 'class' }
    const cycle: Cycle = {
      nodes: [nodeA, nodeB],
      path: 'A -> B -> A',
    }
    expect(cycle.nodes).toHaveLength(2)
    expect(cycle.path).toBe('A -> B -> A')
  })

  test('SecurityAlert satisfies the interface shape', () => {
    const alert: SecurityAlert = {
      name: 'SQL Injection',
      risk: 'High',
      confidence: 'High',
      description: 'SQL injection vulnerability found',
      url: 'https://example.com/api',
      solution: 'Use parameterized queries',
      reference: 'https://owasp.org/...',
      cweid: '89',
      wascid: '19',
    }
    expect(alert.name).toBe('SQL Injection')
    expect(alert.risk).toBe('High')
    expect(alert.confidence).toBe('High')
    expect(alert.description).toBe('SQL injection vulnerability found')
    expect(alert.url).toBe('https://example.com/api')
    expect(alert.solution).toBe('Use parameterized queries')
    expect(alert.cweid).toBe('89')
  })

  test('ScanResult satisfies the interface shape', () => {
    const result: ScanResult = {
      alertCount: 5,
      duration: 30000,
      progress: 100,
    }
    expect(result.alertCount).toBe(5)
    expect(result.duration).toBe(30000)
    expect(result.progress).toBe(100)
  })

  test('SpiderResult satisfies the interface shape', () => {
    const result: SpiderResult = {
      urlsFound: 42,
      duration: 15000,
    }
    expect(result.urlsFound).toBe(42)
    expect(result.duration).toBe(15000)
  })

  test('HeaderCheckResult satisfies the interface shape', () => {
    const result: HeaderCheckResult = {
      headers: {
        'X-Frame-Options': 'DENY',
        'Content-Security-Policy': "default-src 'self'",
      },
      missing: ['Strict-Transport-Security'],
      issues: ['HSTS header is missing'],
    }
    expect(result.headers['X-Frame-Options']).toBe('DENY')
    expect(result.missing).toContain('Strict-Transport-Security')
    expect(result.issues).toHaveLength(1)
  })

  test('SslCheckResult satisfies the interface shape', () => {
    const result: SslCheckResult = {
      valid: true,
      expiresAt: new Date('2025-12-31'),
      issuer: "Let's Encrypt",
      issues: [],
    }
    expect(result.valid).toBe(true)
    expect(result.expiresAt).toBeInstanceOf(Date)
    expect(result.issuer).toBe("Let's Encrypt")
    expect(result.issues).toHaveLength(0)
  })

  test('Variable satisfies the interface shape', () => {
    const variable: Variable = {
      name: 'userId',
      value: '12345',
    }
    expect(variable.name).toBe('userId')
    expect(variable.value).toBe('12345')
  })
})
