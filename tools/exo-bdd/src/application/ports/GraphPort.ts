import type { GraphNode, Dependency, Cycle, LayerInfo, QueryResult } from '../../domain/entities/index.ts'
import type { NodeType } from '../../domain/value-objects/index.ts'
import type { GraphAdapterConfig } from '../config/ConfigSchema.ts'

export interface GraphPort {
  // Configuration
  readonly config: GraphAdapterConfig

  // Connection
  connect(): Promise<void>
  disconnect(): Promise<void>

  // Raw Cypher queries
  query<T = Record<string, unknown>>(
    cypher: string,
    params?: Record<string, unknown>
  ): Promise<T[]>

  // Result accessors (from last query)
  readonly result: QueryResult
  readonly records: Record<string, unknown>[]
  readonly count: number

  // High-level helpers: Layers
  getLayer(name: string): Promise<LayerInfo>
  getNodesInLayer(layer: string, type?: NodeType): Promise<GraphNode[]>
  getLayerDependencies(from: string, to: string): Promise<Dependency[]>

  // High-level helpers: Dependencies
  getDependencies(nodeFqn: string): Promise<Dependency[]>
  getDependents(nodeFqn: string): Promise<Dependency[]>
  findCircularDependencies(): Promise<Cycle[]>
  findCircularDependenciesInLayer(layer: string): Promise<Cycle[]>

  // High-level helpers: Interfaces
  getClassesImplementing(interfaceName: string): Promise<GraphNode[]>
  getClassesNotImplementingAnyInterface(): Promise<GraphNode[]>
  getInterfacesInLayer(layer: string): Promise<GraphNode[]>

  // High-level helpers: Search
  findNodes(pattern: string, type?: NodeType): Promise<GraphNode[]>
  findNodesByLayer(layer: string, type?: NodeType): Promise<GraphNode[]>

  // Lifecycle
  dispose(): Promise<void>
}
