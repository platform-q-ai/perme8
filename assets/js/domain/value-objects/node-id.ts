/**
 * NodeId Value Object
 *
 * Represents a unique identifier for an agent response node in the editor.
 * This is a value object in the domain layer - pure business logic with no dependencies.
 *
 * Responsibilities:
 * - Validate node ID format
 * - Generate unique node IDs
 * - Provide equality comparison
 */
export class NodeId {
  private readonly _value: string

  constructor(value: string) {
    if (!value || value.trim().length === 0) {
      throw new Error('Node ID cannot be empty')
    }

    this._value = value
  }

  get value(): string {
    return this._value
  }

  /**
   * Generate a unique node ID
   *
   * Format: agent_node_{timestamp}_{random}
   * Example: agent_node_1234567890_abc123def
   */
  static generate(): NodeId {
    const timestamp = Date.now()
    const random = Math.random().toString(36).substring(2, 11)
    return new NodeId(`agent_node_${timestamp}_${random}`)
  }

  /**
   * Check equality with another NodeId
   */
  equals(other: NodeId): boolean {
    return this._value === other._value
  }

  /**
   * String representation
   */
  toString(): string {
    return this._value
  }
}
