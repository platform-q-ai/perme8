import { GherkinClassicTokenMatcher, Parser, AstBuilder } from '@cucumber/gherkin'
import { IdGenerator } from '@cucumber/messages'

const parser = new Parser(new AstBuilder(IdGenerator.uuid()), new GherkinClassicTokenMatcher())

// Get file paths from command-line arguments
const paths = process.argv.slice(2).filter(Boolean)

if (paths.length === 0) {
  // Fall back to reading from stdin
  let input = ''
  for await (const chunk of Bun.stdin.stream()) {
    input += new TextDecoder().decode(chunk)
  }
  paths.push(...input.trim().split('\n').filter(Boolean))
}

const results = []

for (const path of paths) {
  try {
    const content = await Bun.file(path).text()
    const gherkinDocument = parser.parse(content)
    results.push({ uri: path, gherkinDocument, error: null })
  } catch (e) {
    results.push({ uri: path, gherkinDocument: null, error: e.message })
  }
}

console.log(JSON.stringify(results))
