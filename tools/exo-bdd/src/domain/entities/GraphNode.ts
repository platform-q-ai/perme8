import type { NodeType } from '../value-objects/NodeType.ts'

export interface GraphNode {
  readonly name: string
  readonly fqn: string
  readonly type: NodeType
  readonly layer?: string
  readonly file?: string
}

export type DependencyType = 'imports' | 'implements' | 'extends' | 'depends_on'

export interface Dependency {
  readonly from: GraphNode
  readonly to: GraphNode
  readonly type: DependencyType
}

export interface Cycle {
  readonly nodes: GraphNode[]
  readonly path: string
}

export interface LayerInfo {
  readonly name: string
  readonly nodeCount: number
  readonly classCount: number
  readonly interfaceCount: number
}

export interface QueryResult {
  readonly records: Record<string, unknown>[]
  readonly count: number
}

export interface ScreenshotOptions {
  readonly fullPage?: boolean
  readonly clip?: { x: number; y: number; width: number; height: number }
  readonly type?: 'png' | 'jpeg'
  readonly quality?: number
  readonly path?: string
}
