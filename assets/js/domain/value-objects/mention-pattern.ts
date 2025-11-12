/**
 * MentionPattern Value Object
 *
 * Represents a mention pattern (e.g., "@j") for detecting agent mentions in text.
 * This is a value object in the domain layer - pure business logic with no dependencies.
 *
 * Responsibilities:
 * - Validate mention pattern format
 * - Match text against pattern
 * - Extract question from mention
 * - Find mention position in text
 */
export class MentionPattern {
  private readonly _value: string
  private readonly regex: RegExp

  constructor(value: string) {
    if (!value || value.trim().length === 0) {
      throw new Error('Mention pattern cannot be empty')
    }

    if (!value.startsWith('@')) {
      throw new Error('Mention pattern must start with @')
    }

    this._value = value
    // Create regex: @j followed by whitespace and any text
    // The pattern is case-insensitive and captures everything after @j
    const escapedPattern = value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    this.regex = new RegExp(`${escapedPattern}\\s+(.+)`, 'i')
  }

  get value(): string {
    return this._value
  }

  /**
   * Check if text contains the mention pattern
   */
  matches(text: string): boolean {
    return this.regex.test(text)
  }

  /**
   * Extract the question from a mention in text
   * Returns null if no mention found or question is empty
   */
  extract(text: string): string | null {
    const match = text.match(this.regex)
    if (!match || !match[1]) {
      return null
    }

    const question = match[1].trim()
    return question.length > 0 ? question : null
  }

  /**
   * Find mention at cursor position in text
   * Returns null if cursor is not within a mention
   */
  findInText(text: string, cursorPos: number): { from: number; to: number; text: string } | null {
    // Match mention from @j to sentence boundary (?, !, .) or end of text/line
    // This ensures we capture complete questions
    const escapedPattern = this._value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    const findRegex = new RegExp(`(${escapedPattern}\\s+[^?!.\\n]+[?!.]?)`, 'gi')
    let match: RegExpExecArray | null

    while ((match = findRegex.exec(text)) !== null) {
      const from = match.index
      const to = from + match[0].length

      // Check if cursor is within this mention
      if (cursorPos >= from && cursorPos <= to) {
        return {
          from,
          to,
          text: match[0]
        }
      }
    }

    return null
  }

  /**
   * Check equality with another MentionPattern
   */
  equals(other: MentionPattern): boolean {
    return this._value === other._value
  }
}
