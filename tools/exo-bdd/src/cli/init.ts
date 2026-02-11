import { resolve, join } from 'node:path'
import { mkdirSync, existsSync } from 'node:fs'
import { generateConfigContent, configFileName } from './templates/config.ts'

export interface InitOptions {
  name: string
  dir?: string
}

export function parseInitArgs(args: string[]): InitOptions {
  let name: string | undefined
  let dir: string | undefined

  for (let i = 0; i < args.length; i++) {
    const arg = args[i]
    if (arg === '--name' || arg === '-n') {
      name = args[++i]
    } else if (arg === '--dir' || arg === '-d') {
      dir = args[++i]
    }
  }

  if (!name) {
    throw new Error('Missing required argument: --name <project-name>')
  }

  return { name, dir }
}

export async function runInit(options: InitOptions): Promise<{ configPath: string; featuresDir: string }> {
  const targetDir = resolve(options.dir ?? process.cwd())
  const fileName = configFileName(options.name)
  const configPath = join(targetDir, fileName)
  const featuresDir = join(targetDir, 'features')

  // Ensure target directory exists
  if (!existsSync(targetDir)) {
    mkdirSync(targetDir, { recursive: true })
  }

  // Check if config already exists
  if (existsSync(configPath)) {
    throw new Error(`Config file already exists: ${configPath}`)
  }

  // Write config file
  const content = generateConfigContent(options.name)
  await Bun.write(configPath, content)

  // Create features directory
  if (!existsSync(featuresDir)) {
    mkdirSync(featuresDir, { recursive: true })
  }

  return { configPath, featuresDir }
}
