import type { ExoBddConfig } from './ConfigSchema.ts'
import { pathToFileURL } from 'node:url'
import { resolve } from 'node:path'

export async function loadConfig(configPath?: string): Promise<ExoBddConfig> {
  const path = configPath ?? resolve(process.cwd(), 'exo-bdd.config.ts')

  const file = Bun.file(path)
  if (!(await file.exists())) {
    throw new Error(
      `Config file not found: ${path}. ` +
      `Create an exo-bdd.config.ts file or pass a custom path to loadConfig().`
    )
  }

  let module: Record<string, unknown>
  try {
    module = await import(pathToFileURL(path).href)
  } catch (error) {
    throw new Error(
      `Failed to load config file: ${path}. ${error instanceof Error ? error.message : String(error)}`
    )
  }

  if (!module.default) {
    throw new Error(
      `Config file ${path} does not have a default export. ` +
      `Use "export default defineConfig({ ... })" to export your configuration.`
    )
  }

  return module.default as ExoBddConfig
}

export function defineConfig(config: ExoBddConfig): ExoBddConfig {
  return config
}
