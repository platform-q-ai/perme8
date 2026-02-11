import { test, expect, describe, beforeEach, mock } from 'bun:test'
import type { GraphAdapterConfig } from '../../src/application/config/index.ts'
import type { NodeType } from '../../src/domain/value-objects/index.ts'
import type { DependencyType } from '../../src/domain/entities/index.ts'

// --- Mock neo4j-driver ---

type MockRecord = { toObject: () => Record<string, unknown> }
type RunResult = { records: MockRecord[] }

const mockClose = mock<() => Promise<void>>(() => Promise.resolve())
const mockSessionClose = mock<() => Promise<void>>(() => Promise.resolve())
const mockRun = mock<(cypher: string, params?: Record<string, unknown>) => Promise<RunResult>>(
  () => Promise.resolve({ records: [] as MockRecord[] }),
)

const mockSession = {
  run: mockRun,
  close: mockSessionClose,
}

const mockDriverSession = mock<() => typeof mockSession>(() => mockSession)
const mockDriverClose = mockClose

const mockDriver = {
  session: mockDriverSession,
  close: mockDriverClose,
}

const mockNeo4jDriver = mock<() => typeof mockDriver>(() => mockDriver)
const mockBasicAuth = mock((user: string, pass: string) => ({
  principal: user,
  credentials: pass,
}))

mock.module('neo4j-driver', () => ({
  default: {
    driver: mockNeo4jDriver,
    auth: { basic: mockBasicAuth },
  },
}))

// Import after mocking
const { Neo4jGraphAdapter } = await import(
  '../../src/infrastructure/adapters/graph/Neo4jGraphAdapter.ts'
)

// --- Helpers ---

const defaultConfig: GraphAdapterConfig = {
  uri: 'bolt://localhost:7687',
  username: 'neo4j',
  password: 's3cret',
  database: 'testdb',
}

function makeRecord(obj: Record<string, unknown>): MockRecord {
  return { toObject: () => obj }
}

function resetMocks() {
  mockRun.mockReset()
  mockClose.mockReset()
  mockSessionClose.mockReset()
  mockDriverSession.mockReset()
  mockNeo4jDriver.mockReset()
  mockBasicAuth.mockReset()

  // Restore default implementations
  mockRun.mockImplementation(() => Promise.resolve({ records: [] as MockRecord[] }))
  mockDriverSession.mockImplementation(() => mockSession)
  mockNeo4jDriver.mockImplementation(() => mockDriver)
  mockBasicAuth.mockImplementation((user: string, pass: string) => ({
    principal: user,
    credentials: pass,
  }))
}

async function createConnectedAdapter(config = defaultConfig) {
  const adapter = new Neo4jGraphAdapter(config)
  await adapter.connect()
  return adapter
}

// --- Tests ---

describe('Neo4jGraphAdapter', () => {
  beforeEach(() => {
    resetMocks()
  })

  // 1
  test('connect creates driver with URI and credentials', async () => {
    await createConnectedAdapter()

    expect(mockNeo4jDriver).toHaveBeenCalledTimes(1)
    expect(mockNeo4jDriver).toHaveBeenCalledWith(
      defaultConfig.uri,
      expect.objectContaining({
        principal: defaultConfig.username,
        credentials: defaultConfig.password,
      }),
    )
    expect(mockBasicAuth).toHaveBeenCalledWith(
      defaultConfig.username,
      defaultConfig.password,
    )
  })

  // 2
  test('connect opens session with configured database', async () => {
    await createConnectedAdapter()

    expect(mockDriverSession).toHaveBeenCalledTimes(1)
    expect(mockDriverSession).toHaveBeenCalledWith({ database: 'testdb' })
  })

  // 2b – default database fallback
  test('connect defaults to neo4j database when not configured', async () => {
    const config: GraphAdapterConfig = {
      uri: 'bolt://localhost:7687',
      username: 'neo4j',
      password: 'pass',
    }
    await createConnectedAdapter(config)

    expect(mockDriverSession).toHaveBeenCalledWith({ database: 'neo4j' })
  })

  // 3
  test('disconnect closes session and driver', async () => {
    const adapter = await createConnectedAdapter()

    await adapter.disconnect()

    expect(mockSessionClose).toHaveBeenCalledTimes(1)
    expect(mockClose).toHaveBeenCalledTimes(1)
  })

  // 4
  test('query executes Cypher and returns mapped records', async () => {
    const adapter = await createConnectedAdapter()
    const expected = [
      { name: 'UserService', fqn: 'app.UserService' },
      { name: 'OrderService', fqn: 'app.OrderService' },
    ]
    mockRun.mockResolvedValueOnce({
      records: expected.map(makeRecord),
    })

    const results = await adapter.query('MATCH (n) RETURN n', { limit: 10 })

    expect(mockRun).toHaveBeenCalledWith('MATCH (n) RETURN n', { limit: 10 })
    expect(results).toEqual(expected)
    expect(adapter.result).toEqual({ records: expected, count: 2 })
    expect(adapter.records).toEqual(expected)
    expect(adapter.count).toBe(2)
  })

  // 5
  test('query with empty result returns empty array', async () => {
    const adapter = await createConnectedAdapter()
    mockRun.mockResolvedValueOnce({ records: [] })

    const results = await adapter.query('MATCH (n) RETURN n')

    expect(results).toEqual([])
    expect(adapter.count).toBe(0)
    expect(adapter.records).toEqual([])
  })

  // 6
  test('getNodesInLayer queries correct Cypher', async () => {
    const adapter = await createConnectedAdapter()
    const nodes = [
      { name: 'Repo', fqn: 'infra.Repo', type: 'class' as NodeType, layer: 'infrastructure', file: 'Repo.ts' },
    ]
    mockRun.mockResolvedValueOnce({ records: nodes.map(makeRecord) })

    const result = await adapter.getNodesInLayer('infrastructure')

    expect(result).toEqual(nodes)
    const call = mockRun.mock.calls[0]!
    const cypher = call[0]
    expect(cypher).toContain('MATCH (n)-[:BELONGS_TO]->(l:Layer {name: $layer})')
    expect(call[1]).toEqual({ layer: 'infrastructure', type: undefined })
  })

  // 7
  test('getNodesInLayer with type filter', async () => {
    const adapter = await createConnectedAdapter()
    mockRun.mockResolvedValueOnce({ records: [] })

    await adapter.getNodesInLayer('domain', 'interface')

    const call = mockRun.mock.calls[0]!
    const cypher = call[0]
    expect(cypher).toContain('toLower(labels(n)[0]) = $type')
    expect(call[1]).toEqual({ layer: 'domain', type: 'interface' })
  })

  // 8
  test('getNodesInLayer without type filter', async () => {
    const adapter = await createConnectedAdapter()
    mockRun.mockResolvedValueOnce({ records: [] })

    await adapter.getNodesInLayer('domain')

    const call = mockRun.mock.calls[0]!
    const cypher = call[0]
    expect(cypher).not.toContain('toLower(labels(n)[0]) = $type')
  })

  // 9
  test('getLayerDependencies returns dependencies between layers', async () => {
    const adapter = await createConnectedAdapter()
    const deps = [
      {
        from: { name: 'Service', fqn: 'app.Service', type: 'class' as NodeType },
        to: { name: 'Repo', fqn: 'infra.Repo', type: 'class' as NodeType },
        type: 'imports' as DependencyType,
      },
    ]
    mockRun.mockResolvedValueOnce({ records: deps.map(makeRecord) })

    const result = await adapter.getLayerDependencies('application', 'infrastructure')

    expect(result).toEqual(deps)
    const call = mockRun.mock.calls[0]!
    const cypher = call[0]
    expect(cypher).toContain(':IMPORTS|DEPENDS_ON')
    expect(cypher).toContain('fl:Layer {name: $from}')
    expect(cypher).toContain('tl:Layer {name: $to}')
    expect(call[1]).toEqual({ from: 'application', to: 'infrastructure' })
  })

  // 10
  test('getLayerDependencies returns empty when no deps', async () => {
    const adapter = await createConnectedAdapter()
    mockRun.mockResolvedValueOnce({ records: [] })

    const result = await adapter.getLayerDependencies('domain', 'infrastructure')

    expect(result).toEqual([])
    expect(adapter.count).toBe(0)
  })

  // 11
  test('findCircularDependencies detects cycles', async () => {
    const adapter = await createConnectedAdapter()
    const cycles = [
      {
        nodes: [
          { name: 'A', fqn: 'app.A', type: 'class' as NodeType },
          { name: 'B', fqn: 'app.B', type: 'class' as NodeType },
          { name: 'A', fqn: 'app.A', type: 'class' as NodeType },
        ],
        path: 'app.A -> app.B -> app.A',
      },
    ]
    mockRun.mockResolvedValueOnce({ records: cycles.map(makeRecord) })

    const result = await adapter.findCircularDependencies()

    expect(result).toEqual(cycles)
    const call = mockRun.mock.calls[0]!
    const cypher = call[0]
    expect(cypher).toContain('MATCH path = (n)-[:IMPORTS|DEPENDS_ON*2..10]->(n)')
    expect(cypher).toContain('LIMIT 100')
  })

  // 12
  test('findCircularDependencies returns empty when clean', async () => {
    const adapter = await createConnectedAdapter()
    mockRun.mockResolvedValueOnce({ records: [] })

    const result = await adapter.findCircularDependencies()

    expect(result).toEqual([])
  })

  // 13
  test('getClassesImplementing finds implementing classes', async () => {
    const adapter = await createConnectedAdapter()
    const classes = [
      { name: 'SqlRepo', fqn: 'infra.SqlRepo', type: 'class' as NodeType, layer: 'infrastructure', file: 'SqlRepo.ts' },
    ]
    mockRun.mockResolvedValueOnce({ records: classes.map(makeRecord) })

    const result = await adapter.getClassesImplementing('Repository')

    expect(result).toEqual(classes)
    const call = mockRun.mock.calls[0]!
    const cypher = call[0]
    expect(cypher).toContain(':IMPLEMENTS')
    expect(cypher).toContain(':Interface {name: $interfaceName}')
    expect(call[1]).toEqual({ interfaceName: 'Repository' })
  })

  // 14
  test('getClassesImplementing returns empty for unknown interface', async () => {
    const adapter = await createConnectedAdapter()
    mockRun.mockResolvedValueOnce({ records: [] })

    const result = await adapter.getClassesImplementing('NonExistent')

    expect(result).toEqual([])
    expect(adapter.count).toBe(0)
  })

  // 15
  test('dispose delegates to disconnect', async () => {
    const adapter = await createConnectedAdapter()

    await adapter.dispose()

    expect(mockSessionClose).toHaveBeenCalledTimes(1)
    expect(mockClose).toHaveBeenCalledTimes(1)
  })
})
