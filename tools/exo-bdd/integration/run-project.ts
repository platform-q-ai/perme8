import { resolve } from 'node:path'

const [project, ...rest] = process.argv.slice(2)
if (!project) {
  console.error('Usage: bun run test:project <project> [cucumber-js args...]')
  process.exit(1)
}

const root = resolve(import.meta.dir, '..')
const configPath = `integration/projects/${project}/cucumber.yml`

const proc = Bun.spawn(
  ['bun', 'node_modules/.bin/cucumber-js', '--config', configPath, ...rest],
  { stdout: 'inherit', stderr: 'inherit', cwd: root }
)

process.exit(await proc.exited)
