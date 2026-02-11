import { test, expect, describe } from 'bun:test'
import type {
  ExoBddConfig,
  HttpAdapterConfig,
  BrowserAdapterConfig,
  CliAdapterConfig,
  GraphAdapterConfig,
  SecurityAdapterConfig,
} from '../../src/application/config/ConfigSchema.ts'

describe('ConfigSchema type validation', () => {
  test('ExoBddConfig with all adapters configured', () => {
    const config: ExoBddConfig = {
      adapters: {
        http: { baseURL: 'http://localhost:3000' },
        browser: { baseURL: 'http://localhost:3000' },
        cli: { workingDir: '/tmp' },
        graph: { uri: 'bolt://localhost:7687', username: 'neo4j', password: 'pass' },
        security: { zapUrl: 'http://localhost:8080' },
      },
    }
    expect(config.adapters.http).toBeDefined()
    expect(config.adapters.browser).toBeDefined()
    expect(config.adapters.cli).toBeDefined()
    expect(config.adapters.graph).toBeDefined()
    expect(config.adapters.security).toBeDefined()
  })

  test('ExoBddConfig with no adapters', () => {
    const config: ExoBddConfig = {
      adapters: {},
    }
    expect(config.adapters).toBeDefined()
    expect(config.adapters.http).toBeUndefined()
    expect(config.adapters.browser).toBeUndefined()
    expect(config.adapters.cli).toBeUndefined()
    expect(config.adapters.graph).toBeUndefined()
    expect(config.adapters.security).toBeUndefined()
  })

  test('ExoBddConfig with only HTTP adapter', () => {
    const config: ExoBddConfig = {
      adapters: {
        http: { baseURL: 'https://api.example.com' },
      },
    }
    expect(config.adapters.http?.baseURL).toBe('https://api.example.com')
    expect(config.adapters.browser).toBeUndefined()
  })

  test('HttpAdapterConfig requires baseURL', () => {
    const config: HttpAdapterConfig = {
      baseURL: 'https://api.example.com',
    }
    expect(config.baseURL).toBe('https://api.example.com')
    expect(config.timeout).toBeUndefined()
    expect(config.headers).toBeUndefined()
    expect(config.auth).toBeUndefined()
  })

  test('HttpAdapterConfig with auth bearer config', () => {
    const config: HttpAdapterConfig = {
      baseURL: 'https://api.example.com',
      auth: {
        type: 'bearer',
        token: 'my-secret-token',
      },
    }
    expect(config.auth?.type).toBe('bearer')
    expect(config.auth?.token).toBe('my-secret-token')
  })

  test('HttpAdapterConfig with auth basic config', () => {
    const config: HttpAdapterConfig = {
      baseURL: 'https://api.example.com',
      auth: {
        type: 'basic',
        username: 'admin',
        password: 'pass123',
      },
    }
    expect(config.auth?.type).toBe('basic')
    expect(config.auth?.username).toBe('admin')
    expect(config.auth?.password).toBe('pass123')
  })

  test('BrowserAdapterConfig defaults', () => {
    const config: BrowserAdapterConfig = {
      baseURL: 'http://localhost:3000',
    }
    expect(config.baseURL).toBe('http://localhost:3000')
    expect(config.headless).toBeUndefined()
    expect(config.viewport).toBeUndefined()
    expect(config.screenshot).toBeUndefined()
    expect(config.video).toBeUndefined()
  })

  test('CliAdapterConfig with all options', () => {
    const config: CliAdapterConfig = {
      workingDir: '/home/user/project',
      shell: '/bin/bash',
      timeout: 30000,
      env: { NODE_ENV: 'test', DEBUG: 'true' },
    }
    expect(config.workingDir).toBe('/home/user/project')
    expect(config.shell).toBe('/bin/bash')
    expect(config.timeout).toBe(30000)
    expect(config.env?.NODE_ENV).toBe('test')
    expect(config.env?.DEBUG).toBe('true')
  })

  test('GraphAdapterConfig requires uri, username, password', () => {
    const config: GraphAdapterConfig = {
      uri: 'bolt://localhost:7687',
      username: 'neo4j',
      password: 'secret',
    }
    expect(config.uri).toBe('bolt://localhost:7687')
    expect(config.username).toBe('neo4j')
    expect(config.password).toBe('secret')
    expect(config.database).toBeUndefined()
  })

  test('SecurityAdapterConfig requires zapUrl', () => {
    const config: SecurityAdapterConfig = {
      zapUrl: 'http://localhost:8080',
    }
    expect(config.zapUrl).toBe('http://localhost:8080')
    expect(config.zapApiKey).toBeUndefined()
  })
})
