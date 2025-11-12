/**
 * UserColor Value Object
 *
 * Represents a color in the domain using hex color notation.
 * Immutable value object that encapsulates color validation and conversion.
 *
 * This is a pure domain value object with no framework dependencies.
 * It ensures colors are valid hex values and provides RGB conversion utilities.
 *
 * @example
 * ```typescript
 * const color = new UserColor('#FF6B6B')
 * console.log(color.toRgbString()) // 'rgb(255, 107, 107)'
 * ```
 *
 * @module domain/value-objects
 */

/**
 * RGB color representation
 */
export interface RgbColor {
  r: number
  g: number
  b: number
}

export class UserColor {
  /**
   * The immutable hex color value (always uppercase)
   * @readonly
   */
  public readonly hex: string

  /**
   * Regex pattern for validating hex colors (both 3 and 6 character formats)
   */
  private static readonly HEX_PATTERN = /^#([0-9A-Fa-f]{3}|[0-9A-Fa-f]{6})$/

  /**
   * Creates a new UserColor value object
   *
   * @param hex - The hex color string (e.g., '#FF6B6B' or '#F00')
   * @throws {Error} If the hex value is invalid
   *
   * @example
   * ```typescript
   * const color1 = new UserColor('#FF6B6B') // Valid 6-char
   * const color2 = new UserColor('#F00') // Valid 3-char shorthand
   * const invalid = new UserColor('FF6B6B') // Throws Error (no #)
   * ```
   */
  constructor(hex: string) {
    if (!hex || !UserColor.HEX_PATTERN.test(hex)) {
      throw new Error('Invalid hex color')
    }

    this.hex = hex.toUpperCase()
  }

  /**
   * Convert hex color to RGB components
   *
   * Supports both 3-character (#F00) and 6-character (#FF0000) hex formats.
   *
   * @returns RGB color object with r, g, b values (0-255)
   *
   * @example
   * ```typescript
   * const color = new UserColor('#FF6B6B')
   * const rgb = color.toRgb()
   * console.log(rgb) // { r: 255, g: 107, b: 107 }
   * ```
   */
  toRgb(): RgbColor {
    const hex = this.hex.slice(1) // Remove #

    // Handle 3-character shorthand (#F00 -> #FF0000)
    const fullHex = hex.length === 3
      ? hex.split('').map(char => char + char).join('')
      : hex

    const r = parseInt(fullHex.slice(0, 2), 16)
    const g = parseInt(fullHex.slice(2, 4), 16)
    const b = parseInt(fullHex.slice(4, 6), 16)

    return { r, g, b }
  }

  /**
   * Convert hex color to RGB string format
   *
   * @returns RGB string in format 'rgb(r, g, b)'
   *
   * @example
   * ```typescript
   * const color = new UserColor('#FF6B6B')
   * console.log(color.toRgbString()) // 'rgb(255, 107, 107)'
   * ```
   */
  toRgbString(): string {
    const { r, g, b } = this.toRgb()
    return `rgb(${r}, ${g}, ${b})`
  }

  /**
   * Check value equality with another UserColor
   *
   * Two UserColors are equal if they have the same hex value (case-insensitive).
   * This implements value equality semantics (not reference equality).
   *
   * @param other - The UserColor to compare with
   * @returns true if both UserColors have the same hex value
   *
   * @example
   * ```typescript
   * const color1 = new UserColor('#FF6B6B')
   * const color2 = new UserColor('#ff6b6b')
   * const color3 = new UserColor('#4ECDC4')
   * console.log(color1.equals(color2)) // true (case-insensitive)
   * console.log(color1.equals(color3)) // false
   * ```
   */
  equals(other: UserColor): boolean {
    return this.hex === other.hex
  }

  /**
   * Get string representation of the UserColor
   *
   * @returns The hex color string (uppercase)
   *
   * @example
   * ```typescript
   * const color = new UserColor('#ff6b6b')
   * console.log(color.toString()) // '#FF6B6B'
   * ```
   */
  toString(): string {
    return this.hex
  }
}
