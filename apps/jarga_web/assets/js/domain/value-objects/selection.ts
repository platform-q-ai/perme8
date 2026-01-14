/**
 * Selection Value Object
 *
 * Represents a text selection range in a document.
 * Immutable value object that encapsulates selection positions and provides
 * utilities for working with text selections.
 *
 * This is a pure domain value object with no framework dependencies.
 * It ensures selections are always valid and provides selection-related
 * operations like checking if a position is within the selection.
 *
 * @example
 * ```typescript
 * const selection = new Selection(5, 10)
 * console.log(selection.getLength()) // 5
 * console.log(selection.contains(7)) // true
 * ```
 *
 * @module domain/value-objects
 */

export class Selection {
  /**
   * The immutable anchor position (start of selection drag)
   * @readonly
   */
  public readonly anchor: number

  /**
   * The immutable head position (end of selection drag/cursor position)
   * @readonly
   */
  public readonly head: number

  /**
   * Creates a new Selection value object
   *
   * @param anchor - The anchor position (start of selection drag)
   * @param head - The head position (end of selection drag/cursor position)
   * @throws {Error} If anchor or head is negative
   *
   * @example
   * ```typescript
   * const selection = new Selection(5, 10) // Forward selection
   * const backward = new Selection(10, 5) // Backward selection
   * const collapsed = new Selection(5, 5) // Collapsed (empty) selection
   * ```
   */
  constructor(anchor: number, head: number) {
    if (anchor < 0 || head < 0) {
      throw new Error('Selection positions must be non-negative')
    }

    this.anchor = anchor
    this.head = head
  }

  /**
   * Check if the selection is empty (collapsed)
   *
   * A selection is empty when anchor and head are at the same position.
   *
   * @returns true if selection is collapsed (empty)
   *
   * @example
   * ```typescript
   * const collapsed = new Selection(5, 5)
   * console.log(collapsed.isEmpty()) // true
   *
   * const range = new Selection(5, 10)
   * console.log(range.isEmpty()) // false
   * ```
   */
  isEmpty(): boolean {
    return this.anchor === this.head
  }

  /**
   * Check if the selection is forward (left to right)
   *
   * A selection is forward when anchor is less than head.
   *
   * @returns true if selection goes forward
   *
   * @example
   * ```typescript
   * const forward = new Selection(5, 10)
   * console.log(forward.isForward()) // true
   *
   * const backward = new Selection(10, 5)
   * console.log(backward.isForward()) // false
   * ```
   */
  isForward(): boolean {
    return this.anchor < this.head
  }

  /**
   * Check if the selection is backward (right to left)
   *
   * A selection is backward when anchor is greater than head.
   *
   * @returns true if selection goes backward
   *
   * @example
   * ```typescript
   * const backward = new Selection(10, 5)
   * console.log(backward.isBackward()) // true
   *
   * const forward = new Selection(5, 10)
   * console.log(forward.isBackward()) // false
   * ```
   */
  isBackward(): boolean {
    return this.anchor > this.head
  }

  /**
   * Get the start position of the selection
   *
   * Returns the minimum of anchor and head.
   *
   * @returns The start position (minimum of anchor and head)
   *
   * @example
   * ```typescript
   * const forward = new Selection(5, 10)
   * console.log(forward.getStart()) // 5
   *
   * const backward = new Selection(10, 5)
   * console.log(backward.getStart()) // 5
   * ```
   */
  getStart(): number {
    return Math.min(this.anchor, this.head)
  }

  /**
   * Get the end position of the selection
   *
   * Returns the maximum of anchor and head.
   *
   * @returns The end position (maximum of anchor and head)
   *
   * @example
   * ```typescript
   * const forward = new Selection(5, 10)
   * console.log(forward.getEnd()) // 10
   *
   * const backward = new Selection(10, 5)
   * console.log(backward.getEnd()) // 10
   * ```
   */
  getEnd(): number {
    return Math.max(this.anchor, this.head)
  }

  /**
   * Get the length of the selection
   *
   * Returns the absolute difference between anchor and head.
   *
   * @returns The length of the selection (0 if collapsed)
   *
   * @example
   * ```typescript
   * const selection = new Selection(5, 10)
   * console.log(selection.getLength()) // 5
   *
   * const collapsed = new Selection(5, 5)
   * console.log(collapsed.getLength()) // 0
   * ```
   */
  getLength(): number {
    return Math.abs(this.head - this.anchor)
  }

  /**
   * Check if a position is within the selection range
   *
   * Returns true if the position is between start and end (inclusive).
   *
   * @param position - The position to check
   * @returns true if position is within the selection
   *
   * @example
   * ```typescript
   * const selection = new Selection(5, 10)
   * console.log(selection.contains(7)) // true
   * console.log(selection.contains(5)) // true (inclusive)
   * console.log(selection.contains(10)) // true (inclusive)
   * console.log(selection.contains(15)) // false
   * ```
   */
  contains(position: number): boolean {
    const start = this.getStart()
    const end = this.getEnd()
    return position >= start && position <= end
  }

  /**
   * Check value equality with another Selection
   *
   * Two Selections are equal if they have the same anchor and head values.
   * This implements value equality semantics (not reference equality).
   *
   * @param other - The Selection to compare with
   * @returns true if both Selections have the same anchor and head
   *
   * @example
   * ```typescript
   * const sel1 = new Selection(5, 10)
   * const sel2 = new Selection(5, 10)
   * const sel3 = new Selection(5, 11)
   * console.log(sel1.equals(sel2)) // true
   * console.log(sel1.equals(sel3)) // false
   * ```
   */
  equals(other: Selection): boolean {
    return this.anchor === other.anchor && this.head === other.head
  }
}
