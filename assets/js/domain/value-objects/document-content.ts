/**
 * DocumentContent Value Object
 *
 * Represents the content of a document as a markdown string.
 * Immutable value object that provides document content operations.
 *
 * This is a pure domain value object with no framework dependencies.
 * Content can be empty (new document) or contain markdown text.
 *
 * @example
 * ```typescript
 * const content = new DocumentContent('# Hello World\n\nParagraph text')
 * console.log(content.characterCount()) // 28
 * console.log(content.lineCount()) // 3
 * console.log(content.isEmpty()) // false
 *
 * const emptyDoc = new DocumentContent('')
 * console.log(emptyDoc.isEmpty()) // true
 * ```
 *
 * @module domain/value-objects
 */

export class DocumentContent {
  /**
   * The immutable document content (markdown string)
   * @readonly
   */
  public readonly value: string

  /**
   * Creates a new DocumentContent value object
   *
   * @param value - The markdown content string (can be empty for new documents)
   *
   * @example
   * ```typescript
   * const content = new DocumentContent('# Title\n\nBody text')
   * const emptyDoc = new DocumentContent('') // Valid - new document
   * ```
   */
  constructor(value: string) {
    this.value = value
  }

  /**
   * Get the number of characters in the content
   *
   * Includes all characters: letters, spaces, newlines, and markdown syntax.
   *
   * @returns The total character count
   *
   * @example
   * ```typescript
   * const content = new DocumentContent('# Hello')
   * console.log(content.characterCount()) // 7
   *
   * const empty = new DocumentContent('')
   * console.log(empty.characterCount()) // 0
   * ```
   */
  characterCount(): number {
    return this.value.length
  }

  /**
   * Get the number of lines in the content
   *
   * Lines are counted by splitting on newline characters.
   * Empty content returns 0 lines.
   * Trailing newlines do not create an additional line.
   * Empty lines are counted.
   *
   * @returns The number of lines
   *
   * @example
   * ```typescript
   * const content = new DocumentContent('Line 1\nLine 2\nLine 3')
   * console.log(content.lineCount()) // 3
   *
   * const withEmpty = new DocumentContent('Line 1\n\nLine 3')
   * console.log(withEmpty.lineCount()) // 3 (includes empty line)
   *
   * const empty = new DocumentContent('')
   * console.log(empty.lineCount()) // 0
   * ```
   */
  lineCount(): number {
    if (this.value === '') {
      return 0
    }

    // Split by newlines, filter out empty trailing line if exists
    const lines = this.value.split('\n')

    // If the last character is a newline, we have a trailing newline
    // which shouldn't count as an additional line
    if (this.value.endsWith('\n') && lines[lines.length - 1] === '') {
      return lines.length - 1
    }

    return lines.length
  }

  /**
   * Check if the content is empty
   *
   * Content is considered empty only when it's an empty string.
   * Whitespace-only content is NOT considered empty.
   *
   * @returns true if content is empty string, false otherwise
   *
   * @example
   * ```typescript
   * const empty = new DocumentContent('')
   * console.log(empty.isEmpty()) // true
   *
   * const withText = new DocumentContent('Hello')
   * console.log(withText.isEmpty()) // false
   *
   * const whitespace = new DocumentContent('   ')
   * console.log(whitespace.isEmpty()) // false (not empty)
   * ```
   */
  isEmpty(): boolean {
    return this.value === ''
  }

  /**
   * Check value equality with another DocumentContent
   *
   * Two DocumentContents are equal if they have the same value string.
   * This implements value equality semantics (not reference equality).
   *
   * @param other - The DocumentContent to compare with
   * @returns true if both DocumentContents have the same value
   *
   * @example
   * ```typescript
   * const content1 = new DocumentContent('# Hello')
   * const content2 = new DocumentContent('# Hello')
   * const content3 = new DocumentContent('# Goodbye')
   * console.log(content1.equals(content2)) // true
   * console.log(content1.equals(content3)) // false
   * ```
   */
  equals(other: DocumentContent): boolean {
    return this.value === other.value
  }

  /**
   * Get string representation of the DocumentContent
   *
   * @returns The markdown content string
   *
   * @example
   * ```typescript
   * const content = new DocumentContent('# Markdown')
   * console.log(content.toString()) // '# Markdown'
   * ```
   */
  toString(): string {
    return this.value
  }
}
