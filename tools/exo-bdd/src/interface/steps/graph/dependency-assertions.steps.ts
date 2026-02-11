import { Then } from '@cucumber/cucumber'
import { expect } from '@playwright/test'
import { TestWorld } from '../../world/index.ts'
import type { GraphNode, Cycle } from '../../../domain/entities/index.ts'

export interface DependencyAssertionContext {
  interpolate(value: string): string
  getVariable<T>(name: string): T
  graph: {
    getLayerDependencies(fromLayer: string, toLayer: string): Promise<Array<{ to: { layer?: string; type?: string; name: string }; type: string }>>
    getNodesInLayer(layer: string): Promise<GraphNode[]>
    getDependencies(fqn: string): Promise<Array<{ to: { layer?: string; type?: string; name: string }; type: string }>>
    findCircularDependencies(): Promise<Cycle[]>
    getClassesNotImplementingAnyInterface(): Promise<Array<{ fqn: string }>>
    getInterfacesInLayer(layer: string): Promise<Array<{ name: string }>>
    getClassesImplementing(interfaceName: string): Promise<Array<{ layer?: string }>>
  }
}

// Layer Dependency Assertions (use context from "Given the layer ...")
export async function assertNoDependencyOnLayer(context: DependencyAssertionContext, targetLayer: string): Promise<void> {
  const currentLayer = context.getVariable<string>('_currentLayer')
  const deps = await context.graph.getLayerDependencies(currentLayer, context.interpolate(targetLayer))
  expect(deps).toHaveLength(0)
}

export async function assertOnlyDependsOnLayer(context: DependencyAssertionContext, allowedLayer: string): Promise<void> {
  const currentLayer = context.getVariable<string>('_currentLayer')
  const allowed = context.interpolate(allowedLayer)
  // Get all layers this layer depends on
  const allNodes = await context.graph.getNodesInLayer(currentLayer)
  for (const node of allNodes) {
    const deps = await context.graph.getDependencies(node.fqn)
    for (const dep of deps) {
      if (dep.to.layer && dep.to.layer !== currentLayer) {
        expect(dep.to.layer).toBe(allowed)
      }
    }
  }
}

export async function assertOnlyDependsOnLayers(context: DependencyAssertionContext, docString: string): Promise<void> {
  const currentLayer = context.getVariable<string>('_currentLayer')
  const allowedLayers = docString.split('\n').map((l) => l.trim()).filter(Boolean)
  const allNodes = await context.graph.getNodesInLayer(currentLayer)
  for (const node of allNodes) {
    const deps = await context.graph.getDependencies(node.fqn)
    for (const dep of deps) {
      if (dep.to.layer && dep.to.layer !== currentLayer) {
        expect(allowedLayers).toContain(dep.to.layer)
      }
    }
  }
}

export async function assertMayDependOnLayer(_context: DependencyAssertionContext, _allowedLayer: string): Promise<void> {
  // This is a permissive assertion - just documents that the dependency is allowed
  // No assertion needed, the step exists for documentation purposes
}

export async function assertDependenciesOnLayerAreOnlyInterfaces(context: DependencyAssertionContext, targetLayer: string): Promise<void> {
  const currentLayer = context.getVariable<string>('_currentLayer')
  const deps = await context.graph.getLayerDependencies(currentLayer, context.interpolate(targetLayer))
  for (const dep of deps) {
    expect(dep.to.type).toBe('interface')
  }
}

// Circular Dependency Detection
export function assertNoCyclesFound(context: DependencyAssertionContext): void {
  const cycles = context.getVariable<Cycle[]>('_cycles')
  expect(cycles).toHaveLength(0)
}

export async function assertNoCircularDependencies(context: DependencyAssertionContext): Promise<void> {
  const cycles = await context.graph.findCircularDependencies()
  expect(cycles).toHaveLength(0)
}

// Interface Assertions (use context from "Given all classes ...")
export async function assertEachImplementsInterface(context: DependencyAssertionContext): Promise<void> {
  const nodes = context.getVariable<GraphNode[]>('_selectedNodes')
  const noInterface = await context.graph.getClassesNotImplementingAnyInterface()
  const noInterfaceFqns = new Set(noInterface.map((n) => n.fqn))
  for (const node of nodes) {
    expect(noInterfaceFqns.has(node.fqn)).toBe(false)
  }
}

export async function assertEachImplementsInterfaceFromLayer(context: DependencyAssertionContext, layer: string): Promise<void> {
  const nodes = context.getVariable<GraphNode[]>('_selectedNodes')
  const interfaces = await context.graph.getInterfacesInLayer(context.interpolate(layer))
  const interfaceNames = new Set(interfaces.map((i) => i.name))
  for (const node of nodes) {
    const deps = await context.graph.getDependencies(node.fqn)
    const implementsFromLayer = deps.some(
      (d) => d.type === 'implements' && interfaceNames.has(d.to.name),
    )
    expect(implementsFromLayer).toBe(true)
  }
}

export async function assertEachImplementsInterfaceMatching(context: DependencyAssertionContext, pattern: string): Promise<void> {
  const nodes = context.getVariable<GraphNode[]>('_selectedNodes')
  const regex = new RegExp(context.interpolate(pattern))
  for (const node of nodes) {
    const deps = await context.graph.getDependencies(node.fqn)
    const implementsMatching = deps.some(
      (d) => d.type === 'implements' && regex.test(d.to.name),
    )
    expect(implementsMatching).toBe(true)
  }
}

export async function assertClassesImplementingAreInLayer(
  context: DependencyAssertionContext,
  interfaceName: string,
  expectedLayer: string,
): Promise<void> {
  const classes = await context.graph.getClassesImplementing(context.interpolate(interfaceName))
  for (const cls of classes) {
    expect(cls.layer).toBe(context.interpolate(expectedLayer))
  }
}

// Import Assertions
export async function assertImportsAreOnlyInterfaces(context: DependencyAssertionContext): Promise<void> {
  const nodes = context.getVariable<GraphNode[]>('_selectedNodes')
  for (const node of nodes) {
    const deps = await context.graph.getDependencies(node.fqn)
    const imports = deps.filter((d) => d.type === 'imports')
    for (const imp of imports) {
      expect(imp.to.type).toBe('interface')
    }
  }
}

export async function assertNoDirectImportsFromLayer(context: DependencyAssertionContext, targetLayer: string): Promise<void> {
  const currentLayer = context.getVariable<string>('_currentLayer')
  const deps = await context.graph.getLayerDependencies(currentLayer, context.interpolate(targetLayer))
  const directImports = deps.filter((d) => d.type === 'imports')
  expect(directImports).toHaveLength(0)
}

// Cucumber Registrations
Then<TestWorld>('it should not depend on layer {string}', async function (targetLayer: string) {
  await assertNoDependencyOnLayer(this, targetLayer)
})

Then<TestWorld>('it should only depend on layer {string}', async function (allowedLayer: string) {
  await assertOnlyDependsOnLayer(this, allowedLayer)
})

Then<TestWorld>('it should only depend on layers:', async function (docString: string) {
  await assertOnlyDependsOnLayers(this, docString)
})

Then<TestWorld>('it may depend on layer {string}', async function (allowedLayer: string) {
  await assertMayDependOnLayer(this, allowedLayer)
})

Then<TestWorld>('dependencies on layer {string} should only be interfaces', async function (targetLayer: string) {
  await assertDependenciesOnLayerAreOnlyInterfaces(this, targetLayer)
})

Then<TestWorld>('no cycles should be found', function () {
  assertNoCyclesFound(this)
})

Then<TestWorld>('there should be no circular dependencies', async function () {
  await assertNoCircularDependencies(this)
})

Then<TestWorld>('each should implement an interface', async function () {
  await assertEachImplementsInterface(this)
})

Then<TestWorld>('each should implement an interface from layer {string}', async function (layer: string) {
  await assertEachImplementsInterfaceFromLayer(this, layer)
})

Then<TestWorld>('each should implement an interface matching {string}', async function (pattern: string) {
  await assertEachImplementsInterfaceMatching(this, pattern)
})

Then<TestWorld>(
  'classes implementing {string} should be in layer {string}',
  async function (interfaceName: string, expectedLayer: string) {
    await assertClassesImplementingAreInLayer(this, interfaceName, expectedLayer)
  },
)

Then<TestWorld>('imports should only be interfaces', async function () {
  await assertImportsAreOnlyInterfaces(this)
})

Then<TestWorld>('there should be no direct imports from layer {string}', async function (targetLayer: string) {
  await assertNoDirectImportsFromLayer(this, targetLayer)
})
