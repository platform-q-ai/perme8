import neo4j, { type Driver, type Session } from 'neo4j-driver'
import type { GraphPort } from '../../../application/ports/index.ts'
import type { GraphAdapterConfig } from '../../../application/config/index.ts'
import type { GraphNode, Dependency, Cycle, LayerInfo, QueryResult } from '../../../domain/entities/index.ts'
import type { NodeType } from '../../../domain/value-objects/index.ts'

export class Neo4jGraphAdapter implements GraphPort {
  private driver!: Driver
  private session!: Session
  private _result: QueryResult = { records: [], count: 0 }

  constructor(readonly config: GraphAdapterConfig) {}

  async connect(): Promise<void> {
    this.driver = neo4j.driver(
      this.config.uri,
      neo4j.auth.basic(this.config.username, this.config.password),
    )
    this.session = this.driver.session({
      database: this.config.database ?? 'neo4j',
    })
  }

  async disconnect(): Promise<void> {
    await this.session?.close()
    await this.driver?.close()
  }

  async query<T = Record<string, unknown>>(
    cypher: string,
    params?: Record<string, unknown>,
  ): Promise<T[]> {
    const result = await this.session.run(cypher, params)
    const records = result.records.map((record) => record.toObject() as T)
    this._result = {
      records: records as Record<string, unknown>[],
      count: records.length,
    }
    return records
  }

  // Result accessors
  get result(): QueryResult {
    return this._result
  }

  get records(): Record<string, unknown>[] {
    return this._result.records
  }

  get count(): number {
    return this._result.count
  }

  // High-level helpers: Layers
  async getLayer(name: string): Promise<LayerInfo> {
    const cypher = `
      MATCH (n)-[:BELONGS_TO]->(l:Layer {name: $name})
      WITH l, n
      RETURN l.name AS name,
             count(n) AS nodeCount,
             count(CASE WHEN n:Class THEN 1 END) AS classCount,
             count(CASE WHEN n:Interface THEN 1 END) AS interfaceCount
    `
    const results = await this.query<LayerInfo>(cypher, { name })
    if (results.length === 0) {
      return { name, nodeCount: 0, classCount: 0, interfaceCount: 0 }
    }
    return results[0]!
  }

  async getNodesInLayer(layer: string, type?: NodeType): Promise<GraphNode[]> {
    const typeFilter = type ? `AND toLower(labels(n)[0]) = $type` : ''
    const cypher = `
      MATCH (n)-[:BELONGS_TO]->(l:Layer {name: $layer})
      WHERE true ${typeFilter}
      RETURN n.name AS name, n.fqn AS fqn, toLower(labels(n)[0]) AS type, $layer AS layer, n.file AS file
    `
    return await this.query<GraphNode>(cypher, { layer, type })
  }

  async getLayerDependencies(from: string, to: string): Promise<Dependency[]> {
    const cypher = `
      MATCH (a)-[:BELONGS_TO]->(fl:Layer {name: $from}),
            (b)-[:BELONGS_TO]->(tl:Layer {name: $to}),
            (a)-[r:IMPORTS|DEPENDS_ON]->(b)
      RETURN a AS \`from\`, b AS \`to\`, toLower(type(r)) AS type
    `
    return await this.query<Dependency>(cypher, { from, to })
  }

  // High-level helpers: Dependencies
  async getDependencies(nodeFqn: string): Promise<Dependency[]> {
    const cypher = `
      MATCH (a {fqn: $nodeFqn})-[r:IMPORTS|IMPLEMENTS|EXTENDS|DEPENDS_ON]->(b)
      RETURN a AS \`from\`, b AS \`to\`, toLower(type(r)) AS type
    `
    return await this.query<Dependency>(cypher, { nodeFqn })
  }

  async getDependents(nodeFqn: string): Promise<Dependency[]> {
    const cypher = `
      MATCH (a)-[r:IMPORTS|IMPLEMENTS|EXTENDS|DEPENDS_ON]->(b {fqn: $nodeFqn})
      RETURN a AS \`from\`, b AS \`to\`, toLower(type(r)) AS type
    `
    return await this.query<Dependency>(cypher, { nodeFqn })
  }

  async findCircularDependencies(): Promise<Cycle[]> {
    const cypher = `
      MATCH path = (n)-[:IMPORTS|DEPENDS_ON*2..10]->(n)
      WITH nodes(path) AS pathNodes
      RETURN pathNodes AS nodes,
             reduce(s = '', node IN pathNodes | s + CASE WHEN s = '' THEN '' ELSE ' -> ' END + node.fqn) AS path
      LIMIT 100
    `
    return await this.query<Cycle>(cypher)
  }

  async findCircularDependenciesInLayer(layer: string): Promise<Cycle[]> {
    const cypher = `
      MATCH path = (n)-[:IMPORTS|DEPENDS_ON*2..10]->(n)
      WHERE ALL(node IN nodes(path) WHERE (node)-[:BELONGS_TO]->(:Layer {name: $layer}))
      WITH nodes(path) AS pathNodes
      RETURN pathNodes AS nodes,
             reduce(s = '', node IN pathNodes | s + CASE WHEN s = '' THEN '' ELSE ' -> ' END + node.fqn) AS path
      LIMIT 100
    `
    return await this.query<Cycle>(cypher, { layer })
  }

  // High-level helpers: Interfaces
  async getClassesImplementing(interfaceName: string): Promise<GraphNode[]> {
    const cypher = `
      MATCH (n:Class)-[:IMPLEMENTS]->(i:Interface {name: $interfaceName})
      RETURN n.name AS name, n.fqn AS fqn, 'class' AS type, n.layer AS layer, n.file AS file
    `
    return await this.query<GraphNode>(cypher, { interfaceName })
  }

  async getClassesNotImplementingAnyInterface(): Promise<GraphNode[]> {
    const cypher = `
      MATCH (n:Class)
      WHERE NOT (n)-[:IMPLEMENTS]->(:Interface)
      RETURN n.name AS name, n.fqn AS fqn, 'class' AS type, n.layer AS layer, n.file AS file
    `
    return await this.query<GraphNode>(cypher)
  }

  async getInterfacesInLayer(layer: string): Promise<GraphNode[]> {
    const cypher = `
      MATCH (n:Interface)-[:BELONGS_TO]->(l:Layer {name: $layer})
      RETURN n.name AS name, n.fqn AS fqn, 'interface' AS type, $layer AS layer, n.file AS file
    `
    return await this.query<GraphNode>(cypher, { layer })
  }

  // High-level helpers: Search
  async findNodes(pattern: string, type?: NodeType): Promise<GraphNode[]> {
    const typeFilter = type ? `AND toLower(labels(n)[0]) = $type` : ''
    const cypher = `
      MATCH (n)
      WHERE n.name =~ $pattern ${typeFilter}
      RETURN n.name AS name, n.fqn AS fqn, toLower(labels(n)[0]) AS type, n.layer AS layer, n.file AS file
    `
    return await this.query<GraphNode>(cypher, { pattern, type })
  }

  async findNodesByLayer(layer: string, type?: NodeType): Promise<GraphNode[]> {
    return await this.getNodesInLayer(layer, type)
  }

  async dispose(): Promise<void> {
    await this.disconnect()
  }
}
