/**
 * UserColorAssignment Policy
 *
 * Domain policy for assigning colors to users based on their ID.
 * Provides deterministic color assignment using a consistent hashing algorithm.
 *
 * This is a pure domain policy with no framework dependencies.
 * The same user ID will always receive the same color.
 *
 * Extracted from: assets/js/collaboration/user-colors.js
 *
 * @example
 * ```typescript
 * const userId = new UserId('user-123')
 * const color = UserColorAssignment.assignColor(userId)
 * console.log(color.hex) // Always the same color for 'user-123'
 * ```
 *
 * @module domain/policies
 */

import { UserId } from '../value-objects/user-id'
import { UserColor } from '../value-objects/user-color'

/**
 * Color palette for user assignment
 */
const COLOR_PALETTE: readonly string[] = Object.freeze([
  '#FF6B6B', // Red
  '#4ECDC4', // Teal
  '#45B7D1', // Blue
  '#FFA07A', // Orange
  '#98D8C8', // Mint
  '#F7DC6F', // Yellow
  '#BB8FCE', // Purple
  '#85C1E2', // Sky Blue
  '#F8B88B', // Peach
  '#7FB3D5', // Light Blue
])

/**
 * User color assignment policy
 *
 * Implements deterministic color assignment for users based on their ID.
 */
export class UserColorAssignment {
  /**
   * Assign a color to a user based on their ID
   *
   * Uses a consistent hash algorithm to ensure the same user ID
   * always receives the same color from the predefined palette.
   *
   * @param userId - The user's ID
   * @returns A UserColor from the predefined palette
   *
   * @example
   * ```typescript
   * const userId = new UserId('user-123')
   * const color = UserColorAssignment.assignColor(userId)
   * console.log(color.hex) // e.g., '#FF6B6B'
   *
   * // Same ID always gets same color
   * const sameColor = UserColorAssignment.assignColor(userId)
   * console.log(color.equals(sameColor)) // true
   * ```
   */
  static assignColor(userId: UserId): UserColor {
    const hash = this.hashString(userId.value)
    const colorIndex = hash % COLOR_PALETTE.length
    const hexColor = COLOR_PALETTE[colorIndex]

    return new UserColor(hexColor)
  }

  /**
   * Get the color palette
   *
   * Returns a copy of the color palette as UserColor objects.
   * The palette is immutable - modifications to the returned array
   * won't affect the original palette.
   *
   * @returns Array of UserColor objects representing the available colors
   *
   * @example
   * ```typescript
   * const palette = UserColorAssignment.getColorPalette()
   * console.log(palette.length) // 10
   * console.log(palette[0].hex) // '#FF6B6B'
   * ```
   */
  static getColorPalette(): UserColor[] {
    return COLOR_PALETTE.map(hex => new UserColor(hex))
  }

  /**
   * Generate a consistent hash from a string
   *
   * Uses a simple hash algorithm that produces the same output
   * for the same input string. The algorithm is the same as used
   * in the original user-colors.js implementation.
   *
   * @private
   * @param str - The string to hash
   * @returns A positive integer hash value
   *
   * @example
   * ```typescript
   * const hash1 = UserColorAssignment.hashString('user-123')
   * const hash2 = UserColorAssignment.hashString('user-123')
   * console.log(hash1 === hash2) // true (deterministic)
   * ```
   */
  private static hashString(str: string): number {
    let hash = 0
    for (let i = 0; i < str.length; i++) {
      hash = str.charCodeAt(i) + ((hash << 5) - hash)
    }
    return Math.abs(hash)
  }
}
