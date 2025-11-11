/**
 * User Color Manager
 *
 * Responsibility: Generate consistent colors for users based on their ID.
 * Follows Single Responsibility Principle - only handles color generation.
 *
 * @module UserColors
 */

const COLOR_PALETTE = [
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
]

/**
 * Generate a consistent hash from a string.
 *
 * @private
 * @param {string} str - Input string
 * @returns {number} Hash value
 */
function hashString(str) {
  let hash = 0
  for (let i = 0; i < str.length; i++) {
    hash = str.charCodeAt(i) + ((hash << 5) - hash)
  }
  return Math.abs(hash)
}

/**
 * Get a color for a user based on their ID.
 * The same user ID will always return the same color.
 *
 * @param {string} userId - User identifier
 * @returns {string} Hex color code
 */
export function getUserColor(userId) {
  const hash = hashString(userId)
  return COLOR_PALETTE[hash % COLOR_PALETTE.length]
}

/**
 * Get the color palette.
 *
 * @returns {string[]} Array of color hex codes
 */
export function getColorPalette() {
  return [...COLOR_PALETTE]
}
