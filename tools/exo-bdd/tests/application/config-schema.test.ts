import { test, expect, describe } from 'bun:test'
import type {
  ExoBddConfig,
  ServerConfig,
  HttpAdapterConfig,
  BrowserAdapterConfig,
  CliAdapterConfig,
  GraphAdapterConfig,
  SecurityAdapterConfig,
  ReportConfig,
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

  test('ExoBddConfig with features as a string', () => {
    const config: ExoBddConfig = {
      features: './features/**/*.feature',
      adapters: {},
    }
    expect(config.features).toBe('./features/**/*.feature')
  })

  test('ExoBddConfig with features as an array', () => {
    const config: ExoBddConfig = {
      features: ['./features/**/*.feature', './extra/**/*.feature'],
      adapters: {},
    }
    expect(config.features).toEqual(['./features/**/*.feature', './extra/**/*.feature'])
  })

  test('ExoBddConfig with features omitted (optional)', () => {
    const config: ExoBddConfig = {
      adapters: {},
    }
    expect(config.features).toBeUndefined()
  })

  test('ServerConfig with required fields only', () => {
    const server: ServerConfig = {
      name: 'my-app',
      command: 'mix phx.server',
      port: 4000,
    }
    expect(server.name).toBe('my-app')
    expect(server.command).toBe('mix phx.server')
    expect(server.port).toBe(4000)
    expect(server.workingDir).toBeUndefined()
    expect(server.env).toBeUndefined()
    expect(server.seed).toBeUndefined()
    expect(server.healthCheckPath).toBeUndefined()
    expect(server.startTimeout).toBeUndefined()
  })

  test('ServerConfig with all options', () => {
    const server: ServerConfig = {
      name: 'jarga-api',
      command: 'mix phx.server',
      port: 4005,
      workingDir: '../../',
      env: { MIX_ENV: 'test' },
      seed: 'mix run priv/repo/exo_seeds.exs',
      healthCheckPath: '/api/health',
      startTimeout: 60000,
    }
    expect(server.name).toBe('jarga-api')
    expect(server.port).toBe(4005)
    expect(server.workingDir).toBe('../../')
    expect(server.env?.MIX_ENV).toBe('test')
    expect(server.seed).toBe('mix run priv/repo/exo_seeds.exs')
    expect(server.healthCheckPath).toBe('/api/health')
    expect(server.startTimeout).toBe(60000)
  })

  test('ExoBddConfig with servers configured', () => {
    const config: ExoBddConfig = {
      servers: [
        {
          name: 'api',
          command: 'mix phx.server',
          port: 4005,
          seed: 'mix run priv/repo/seeds.exs',
        },
        {
          name: 'web',
          command: 'mix phx.server',
          port: 4002,
        },
      ],
      adapters: {
        http: { baseURL: 'http://localhost:4005' },
      },
    }
    expect(config.servers).toHaveLength(2)
    expect(config.servers![0].name).toBe('api')
    expect(config.servers![0].seed).toBe('mix run priv/repo/seeds.exs')
    expect(config.servers![1].name).toBe('web')
  })

  test('ExoBddConfig with servers omitted (optional)', () => {
    const config: ExoBddConfig = {
      adapters: {},
    }
    expect(config.servers).toBeUndefined()
  })

  test('ExoBddConfig with variables configured', () => {
    const config: ExoBddConfig = {
      adapters: {
        http: { baseURL: 'http://localhost:4005' },
      },
      variables: {
        'api-token': 'secret-123',
        'workspace-slug': 'my-workspace',
        'another-key': 'value-456',
      },
    }
    expect(config.variables).toBeDefined()
    expect(Object.keys(config.variables!)).toHaveLength(3)
    expect(config.variables!['api-token']).toBe('secret-123')
    expect(config.variables!['workspace-slug']).toBe('my-workspace')
  })

  test('ExoBddConfig with variables omitted (optional)', () => {
    const config: ExoBddConfig = {
      adapters: {},
    }
    expect(config.variables).toBeUndefined()
  })

  test('ExoBddConfig with empty variables', () => {
    const config: ExoBddConfig = {
      adapters: {},
      variables: {},
    }
    expect(config.variables).toBeDefined()
    expect(Object.keys(config.variables!)).toHaveLength(0)
  })
})

describe('ReportConfig type validation', () => {
  test('ReportConfig with message set to true', () => {
    const report: ReportConfig = {
      message: true,
    }
    expect(report.message).toBe(true)
  })

  test('ReportConfig with message set to false', () => {
    const report: ReportConfig = {
      message: false,
    }
    expect(report.message).toBe(false)
  })

  test('ReportConfig with message as object with outputDir', () => {
    const report: ReportConfig = {
      message: { outputDir: '/custom/reports' },
    }
    expect(report.message).toEqual({ outputDir: '/custom/reports' })
  })

  test('ReportConfig with message as object with empty outputDir', () => {
    const report: ReportConfig = {
      message: {},
    }
    expect(report.message).toEqual({})
  })

  test('ReportConfig with message omitted', () => {
    const report: ReportConfig = {}
    expect(report.message).toBeUndefined()
  })

  test('ExoBddConfig accepts report field', () => {
    const config: ExoBddConfig = {
      adapters: {},
      report: {
        message: true,
      },
    }
    expect(config.report).toBeDefined()
    expect(config.report!.message).toBe(true)
  })

  test('ExoBddConfig with report.message as object', () => {
    const config: ExoBddConfig = {
      adapters: {},
      report: {
        message: { outputDir: '/tmp/reports' },
      },
    }
    expect(config.report!.message).toEqual({ outputDir: '/tmp/reports' })
  })

  test('ExoBddConfig without report is backward compatible', () => {
    const config: ExoBddConfig = {
      adapters: {
        http: { baseURL: 'http://localhost:3000' },
      },
    }
    expect(config.report).toBeUndefined()
  })

  test('ExoBddConfig with report and all other fields', () => {
    const config: ExoBddConfig = {
      features: './features/**/*.feature',
      servers: [{ name: 'api', command: 'mix phx.server', port: 4005 }],
      variables: { token: 'abc' },
      timeout: 30000,
      tags: '@smoke',
      adapters: {
        http: { baseURL: 'http://localhost:4005' },
      },
      report: {
        message: true,
      },
    }
    expect(config.report!.message).toBe(true)
    expect(config.features).toBe('./features/**/*.feature')
    expect(config.servers).toHaveLength(1)
    expect(config.variables!['token']).toBe('abc')
  })
})
