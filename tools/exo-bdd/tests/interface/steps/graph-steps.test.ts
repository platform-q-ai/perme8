import { test, expect, describe, beforeEach, mock } from 'bun:test'
import { VariableService } from '../../../src/application/services/VariableService.ts'
import { InterpolationService } from '../../../src/application/services/InterpolationService.ts'
import type { GraphNode, Dependency, Cycle } from '../../../src/domain/entities/index.ts'

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

// Mock @playwright/test so assertion handlers use a working expect
mock.module('@playwright/test', () => ({
  expect,
  default: {},
}))

// Dynamic imports after mocks so Cucumber registrations run harmlessly
const {
  selectAllNodesInLayer,
  selectAllClassesInLayer,
  selectClass,
  queryGraph,
  checkCircularDependencies,
} = await import('../../../src/interface/steps/graph/selection.steps.ts')
const {
  assertNoDependencyOnLayer,
  assertNoCyclesFound,
  assertNoCircularDependencies,
} = await import('../../../src/interface/steps/graph/dependency-assertions.steps.ts')
const {
  assertResultEmpty,
  assertResultRowCount,
  assertResultMinRowCount,
  assertResultPathEquals,
  storeResultCount,
  storeResult,
} = await import('../../../src/interface/steps/graph/query.steps.ts')

/**
 * Tests for graph step definition logic (selection, dependency-assertions, query).
 *
 * These tests import and invoke the actual exported handler functions from
 * the refactored step definition files, passing a mock world that satisfies
 * the context interfaces.
 */

// ─── Helpers ──────────────────────────────────────────────────────────────────

function makeNode(overrides: Partial<GraphNode> = {}): GraphNode {
  return {
    name: overrides.name ?? 'MyClass',
    fqn: overrides.fqn ?? 'com.example.MyClass',
    type: overrides.type ?? 'class',
    layer: overrides.layer,
    file: overrides.file,
  }
}

function makeDep(overrides: Partial<Dependency> = {}): Dependency {
  return {
    from: overrides.from ?? makeNode({ name: 'A', fqn: 'a' }),
    to: overrides.to ?? makeNode({ name: 'B', fqn: 'b' }),
    type: overrides.type ?? 'imports',
  }
}

function makeCycle(nodes: GraphNode[]): Cycle {
  return { nodes, path: nodes.map((n) => n.name).join(' -> ') }
}

interface MockGraphPort {
  getLayer: ReturnType<typeof mock>
  getNodesInLayer: ReturnType<typeof mock>
  getLayerDependencies: ReturnType<typeof mock>
  getDependencies: ReturnType<typeof mock>
  getDependents: ReturnType<typeof mock>
  findCircularDependencies: ReturnType<typeof mock>
  findCircularDependenciesInLayer: ReturnType<typeof mock>
  getClassesImplementing: ReturnType<typeof mock>
  getClassesNotImplementingAnyInterface: ReturnType<typeof mock>
  getInterfacesInLayer: ReturnType<typeof mock>
  findNodes: ReturnType<typeof mock>
  findNodesByLayer: ReturnType<typeof mock>
  query: ReturnType<typeof mock>
  connect: ReturnType<typeof mock>
  disconnect: ReturnType<typeof mock>
  dispose: ReturnType<typeof mock>
  config: Record<string, unknown>
  records: Record<string, unknown>[]
  count: number
}

function createMockWorld() {
  const variableService = new VariableService()
  const interpolationService = new InterpolationService(variableService)

  const graph: MockGraphPort = {
    getLayer: mock(() => Promise.resolve({ name: 'domain', nodeCount: 5, classCount: 3, interfaceCount: 2 })),
    getNodesInLayer: mock(() => Promise.resolve([] as GraphNode[])),
    getLayerDependencies: mock(() => Promise.resolve([] as Dependency[])),
    getDependencies: mock(() => Promise.resolve([] as Dependency[])),
    getDependents: mock(() => Promise.resolve([] as Dependency[])),
    findCircularDependencies: mock(() => Promise.resolve([] as Cycle[])),
    findCircularDependenciesInLayer: mock(() => Promise.resolve([] as Cycle[])),
    getClassesImplementing: mock(() => Promise.resolve([] as GraphNode[])),
    getClassesNotImplementingAnyInterface: mock(() => Promise.resolve([] as GraphNode[])),
    getInterfacesInLayer: mock(() => Promise.resolve([] as GraphNode[])),
    findNodes: mock(() => Promise.resolve([] as GraphNode[])),
    findNodesByLayer: mock(() => Promise.resolve([] as GraphNode[])),
    query: mock(() => Promise.resolve([])),
    connect: mock(() => Promise.resolve()),
    disconnect: mock(() => Promise.resolve()),
    dispose: mock(() => Promise.resolve()),
    config: {},
    records: [],
    count: 0,
  }

  return {
    graph,
    setVariable: (name: string, value: unknown) => variableService.set(name, value),
    getVariable: <T>(name: string): T => variableService.get<T>(name),
    hasVariable: (name: string) => variableService.has(name),
    interpolate: (text: string) => interpolationService.interpolate(text),
  }
}

type MockWorld = ReturnType<typeof createMockWorld>

// ─── Tests ────────────────────────────────────────────────────────────────────

describe('Graph Steps', () => {
  let world: MockWorld

  beforeEach(() => {
    world = createMockWorld()
  })

  // ═══════════════════════════════════════════════════════════════════════════
  // selection.steps.ts
  // ═══════════════════════════════════════════════════════════════════════════

  describe('Selection Steps', () => {
    // ── Test 1: 'all nodes in layer {string}' calls graph.getNodesInLayer ──
    test('all nodes in layer calls graph.getNodesInLayer', async () => {
      const nodes = [makeNode({ name: 'A', layer: 'domain' })]
      world.graph.getNodesInLayer.mockResolvedValueOnce(nodes)

      await selectAllNodesInLayer(world, 'domain')

      expect(world.graph.getNodesInLayer).toHaveBeenCalledWith('domain')
    })

    // ── Test 2: 'all nodes in layer' stores results as _selectedNodes ──────
    test('all nodes in layer stores results as _selectedNodes', async () => {
      const nodes = [
        makeNode({ name: 'A', layer: 'domain' }),
        makeNode({ name: 'B', layer: 'domain' }),
      ]
      world.graph.getNodesInLayer.mockResolvedValueOnce(nodes)

      await selectAllNodesInLayer(world, 'domain')

      const stored = world.getVariable<GraphNode[]>('_selectedNodes')
      expect(stored).toHaveLength(2)
      expect(stored[0]!.name).toBe('A')
      expect(stored[1]!.name).toBe('B')
    })

    // ── Test 3: 'all classes in layer' filters by type ─────────────────────
    test('all classes in layer filters by type class', async () => {
      const classNodes = [makeNode({ name: 'Svc', type: 'class', layer: 'application' })]
      world.graph.getNodesInLayer.mockResolvedValueOnce(classNodes)

      await selectAllClassesInLayer(world, 'application')

      expect(world.graph.getNodesInLayer).toHaveBeenCalledWith('application', 'class')
      const stored = world.getVariable<GraphNode[]>('_selectedNodes')
      expect(stored).toHaveLength(1)
      expect(stored[0]!.name).toBe('Svc')
    })

    // ── Test 4: 'the class {string}' calls graph.findNodes ─────────────────
    test('the class {string} calls graph.findNodes with class type', async () => {
      const nodes = [makeNode({ name: 'UserService', fqn: 'com.app.UserService' })]
      world.graph.findNodes.mockResolvedValueOnce(nodes)

      await selectClass(world, 'UserService')

      expect(world.graph.findNodes).toHaveBeenCalledWith('UserService', 'class')
      const currentNode = world.getVariable<GraphNode>('_currentNode')
      expect(currentNode.name).toBe('UserService')
    })

    // ── Test 5: 'I query:' docstring calls graph.query ─────────────────────
    test('I query: docstring calls graph.query', async () => {
      world.graph.query.mockResolvedValueOnce([{ n: { name: 'Foo' } }])

      await queryGraph(world, 'MATCH (n) RETURN n')

      expect(world.graph.query).toHaveBeenCalledWith('MATCH (n) RETURN n')
    })

    // ── Test 6: 'I check for circular dependencies' calls findCircularDependencies
    test('I check for circular dependencies calls findCircularDependencies and stores _cycles', async () => {
      const cycles = [makeCycle([makeNode({ name: 'A' }), makeNode({ name: 'B' })])]
      world.graph.findCircularDependencies.mockResolvedValueOnce(cycles)

      await checkCircularDependencies(world)

      expect(world.graph.findCircularDependencies).toHaveBeenCalled()
      const stored = world.getVariable<Cycle[]>('_cycles')
      expect(stored).toHaveLength(1)
      expect(stored[0]!.nodes[0]!.name).toBe('A')
    })
  })

  // ═══════════════════════════════════════════════════════════════════════════
  // dependency-assertions.steps.ts
  // ═══════════════════════════════════════════════════════════════════════════

  describe('Dependency Assertion Steps', () => {
    // ── Test 7: 'it should not depend on layer' passes when empty ──────────
    test('it should not depend on layer passes when no dependencies', async () => {
      world.setVariable('_currentLayer', 'domain')
      world.graph.getLayerDependencies.mockResolvedValueOnce([])

      await assertNoDependencyOnLayer(world, 'infrastructure')

      expect(world.graph.getLayerDependencies).toHaveBeenCalledWith('domain', 'infrastructure')
    })

    // ── Test 8: 'it should not depend on layer' fails when deps exist ──────
    test('it should not depend on layer fails when dependencies exist', async () => {
      world.setVariable('_currentLayer', 'domain')
      const deps = [makeDep({ type: 'imports' })]
      world.graph.getLayerDependencies.mockResolvedValueOnce(deps)

      await expect(
        assertNoDependencyOnLayer(world, 'infrastructure'),
      ).rejects.toThrow()
    })

    // ── Test 9: 'there should be no circular dependencies' passes when none
    test('there should be no circular dependencies passes when none', async () => {
      world.graph.findCircularDependencies.mockResolvedValueOnce([])

      await assertNoCircularDependencies(world)

      expect(world.graph.findCircularDependencies).toHaveBeenCalled()
    })

    // ── Test 10: 'there should be no circular dependencies' fails when found
    test('there should be no circular dependencies fails when cycles found', async () => {
      const cycles = [makeCycle([makeNode({ name: 'X' }), makeNode({ name: 'Y' })])]
      world.graph.findCircularDependencies.mockResolvedValueOnce(cycles)

      await expect(
        assertNoCircularDependencies(world),
      ).rejects.toThrow()
    })

    // ── Test 11: 'no cycles should be found' passes from _cycles variable ──
    test('no cycles should be found passes when _cycles is empty', () => {
      world.setVariable('_cycles', [] as Cycle[])

      assertNoCyclesFound(world)
    })

    // ── Test 12: 'no cycles should be found' fails when cycles exist ───────
    test('no cycles should be found fails when _cycles contains entries', () => {
      const cycles = [makeCycle([makeNode({ name: 'A' }), makeNode({ name: 'B' })])]
      world.setVariable('_cycles', cycles)

      expect(() => {
        assertNoCyclesFound(world)
      }).toThrow()
    })

    // ── Test 19: 'it should not depend on layer' verifies correct params ───
    test('it should not depend on layer calls getLayerDependencies with correct params', async () => {
      world.setVariable('_currentLayer', 'application')
      world.graph.getLayerDependencies.mockResolvedValueOnce([])

      await assertNoDependencyOnLayer(world, 'infrastructure')

      expect(world.graph.getLayerDependencies).toHaveBeenCalledWith('application', 'infrastructure')
    })
  })

  // ═══════════════════════════════════════════════════════════════════════════
  // query.steps.ts
  // ═══════════════════════════════════════════════════════════════════════════

  describe('Query Assertion Steps', () => {
    // ── Test 13: 'the result should be empty' passes when count is 0 ───────
    test('the result should be empty passes when count is 0', () => {
      world.graph.count = 0

      assertResultEmpty(world)
    })

    // ── Test 14: 'the result should have N rows' passes for matching count ─
    test('the result should have N rows passes for matching count', () => {
      world.graph.count = 5

      assertResultRowCount(world, 5)
    })

    // ── Test 15: 'the result should have at least N rows' passes ───────────
    test('the result should have at least N rows passes', () => {
      world.graph.count = 10

      assertResultMinRowCount(world, 5)
    })

    // ── Test 16: 'the result path should equal' passes ─────────────────────
    test('the result path should equal passes for matching value', () => {
      world.graph.records = [{ user: { name: 'Alice' } }]

      assertResultPathEquals(world, 'user.name', 'Alice')
    })

    // ── Test 17: 'I store the result count as' stores count ────────────────
    test('I store the result count as stores count variable', () => {
      world.graph.count = 42

      storeResultCount(world, 'nodeCount')

      expect(world.getVariable<number>('nodeCount')).toBe(42)
    })

    // ── Test 18: 'I store the result as' stores records ────────────────────
    test('I store the result as stores records variable', () => {
      const records = [{ id: 1, name: 'Foo' }, { id: 2, name: 'Bar' }]
      world.graph.records = records

      storeResult(world, 'queryResults')

      const stored = world.getVariable<Record<string, unknown>[]>('queryResults')
      expect(stored).toHaveLength(2)
      expect(stored[0]).toEqual({ id: 1, name: 'Foo' })
    })
  })

  // ═══════════════════════════════════════════════════════════════════════════
  // Additional / Cross-cutting
  // ═══════════════════════════════════════════════════════════════════════════

  describe('Additional Selection Steps', () => {
    // ── Test 20: 'all nodes in layer' stores _selectedNodes and _currentLayer
    test('all nodes in layer stores both _selectedNodes and _currentLayer', async () => {
      const nodes = [
        makeNode({ name: 'Svc', layer: 'application' }),
        makeNode({ name: 'Repo', layer: 'application' }),
      ]
      world.graph.getNodesInLayer.mockResolvedValueOnce(nodes)

      await selectAllNodesInLayer(world, 'application')

      expect(world.getVariable<string>('_currentLayer')).toBe('application')
      const stored = world.getVariable<GraphNode[]>('_selectedNodes')
      expect(stored).toHaveLength(2)
      expect(stored[0]!.name).toBe('Svc')
      expect(stored[1]!.name).toBe('Repo')
    })
  })
})
