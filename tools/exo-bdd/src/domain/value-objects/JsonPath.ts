export class JsonPath {
  constructor(public readonly expression: string) {
    if (!expression.startsWith('$')) {
      throw new Error('JSONPath must start with $')
    }
  }

  toString(): string {
    return this.expression
  }
}
