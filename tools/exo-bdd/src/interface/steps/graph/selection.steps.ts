import { Given, When } from '@cucumber/cucumber'
import { TestWorld } from '../../world/index.ts'
import type { NodeType } from '../../../domain/value-objects/index.ts'

export interface SelectionContext {
  interpolate(value: string): string
  setVariable(name: string, value: unknown): void
  graph: {
    getLayer(name: string): Promise<unknown>
    getNodesInLayer(layer: string, type?: NodeType): Promise<unknown[]>
    findNodes(pattern: string, type: NodeType): Promise<Array<{ fqn: string }>>
    query(query: string): Promise<Record<string, unknown>[]>
    findCircularDependencies(): Promise<unknown[]>
    findCircularDependenciesInLayer(layer: string): Promise<unknown[]>
  }
}

// Layer Selection (sets context for subsequent assertions)
export async function selectLayer(context: SelectionContext, layer: string): Promise<void> {
  const layerName = context.interpolate(layer)
  context.setVariable('_currentLayer', layerName)
  const info = await context.graph.getLayer(layerName)
  context.setVariable('_currentLayerInfo', info)
}

export async function selectAllNodesInLayer(context: SelectionContext, layer: string): Promise<void> {
  const layerName = context.interpolate(layer)
  context.setVariable('_currentLayer', layerName)
  const nodes = await context.graph.getNodesInLayer(layerName)
  context.setVariable('_selectedNodes', nodes)
}

export async function selectAllClassesInLayer(context: SelectionContext, layer: string): Promise<void> {
  const layerName = context.interpolate(layer)
  context.setVariable('_currentLayer', layerName)
  const nodes = await context.graph.getNodesInLayer(layerName, 'class')
  context.setVariable('_selectedNodes', nodes)
}

export async function selectAllInterfacesInLayer(context: SelectionContext, layer: string): Promise<void> {
  const layerName = context.interpolate(layer)
  context.setVariable('_currentLayer', layerName)
  const nodes = await context.graph.getNodesInLayer(layerName, 'interface')
  context.setVariable('_selectedNodes', nodes)
}

// Node Selection
export async function selectAllClassesMatchingPattern(context: SelectionContext, pattern: string): Promise<void> {
  const nodes = await context.graph.findNodes(context.interpolate(pattern), 'class')
  context.setVariable('_selectedNodes', nodes)
}

export async function selectAllClassesInPath(context: SelectionContext, path: string): Promise<void> {
  const nodes = await context.graph.findNodes(`.*${context.interpolate(path)}.*`, 'class')
  context.setVariable('_selectedNodes', nodes)
}

export async function selectAllInterfacesInPath(context: SelectionContext, path: string): Promise<void> {
  const nodes = await context.graph.findNodes(`.*${context.interpolate(path)}.*`, 'interface')
  context.setVariable('_selectedNodes', nodes)
}

export async function selectClass(context: SelectionContext, name: string): Promise<void> {
  const nodes = await context.graph.findNodes(context.interpolate(name), 'class')
  context.setVariable('_selectedNodes', nodes)
  if (nodes.length > 0) {
    context.setVariable('_currentNode', nodes[0])
  }
}

export async function selectModule(context: SelectionContext, name: string): Promise<void> {
  const nodes = await context.graph.findNodes(context.interpolate(name), 'module')
  context.setVariable('_selectedNodes', nodes)
  if (nodes.length > 0) {
    context.setVariable('_currentNode', nodes[0])
  }
}

// Cypher Queries
export async function queryGraph(context: SelectionContext, docString: string): Promise<void> {
  await context.graph.query(context.interpolate(docString))
}

export async function checkCircularDependencies(context: SelectionContext): Promise<void> {
  const cycles = await context.graph.findCircularDependencies()
  context.setVariable('_cycles', cycles)
}

export async function checkCircularDependenciesInLayer(context: SelectionContext, layer: string): Promise<void> {
  const cycles = await context.graph.findCircularDependenciesInLayer(context.interpolate(layer))
  context.setVariable('_cycles', cycles)
}

// Cucumber Registrations
Given<TestWorld>('the layer {string}', async function (layer: string) {
  await selectLayer(this, layer)
})

Given<TestWorld>('all nodes in layer {string}', async function (layer: string) {
  await selectAllNodesInLayer(this, layer)
})

Given<TestWorld>('all classes in layer {string}', async function (layer: string) {
  await selectAllClassesInLayer(this, layer)
})

Given<TestWorld>('all interfaces in layer {string}', async function (layer: string) {
  await selectAllInterfacesInLayer(this, layer)
})

Given<TestWorld>('all classes matching {string}', async function (pattern: string) {
  await selectAllClassesMatchingPattern(this, pattern)
})

Given<TestWorld>('all classes in {string}', async function (path: string) {
  await selectAllClassesInPath(this, path)
})

Given<TestWorld>('all interfaces in {string}', async function (path: string) {
  await selectAllInterfacesInPath(this, path)
})

Given<TestWorld>('the class {string}', async function (name: string) {
  await selectClass(this, name)
})

Given<TestWorld>('the module {string}', async function (name: string) {
  await selectModule(this, name)
})

When<TestWorld>('I query:', async function (docString: string) {
  await queryGraph(this, docString)
})

When<TestWorld>('I check for circular dependencies', async function () {
  await checkCircularDependencies(this)
})

When<TestWorld>('I check for circular dependencies in layer {string}', async function (layer: string) {
  await checkCircularDependenciesInLayer(this, layer)
})
