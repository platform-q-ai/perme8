#!/usr/bin/env bun

const [subcommand, ...rest] = process.argv.slice(2)

switch (subcommand) {
  case 'init': {
    const { parseInitArgs, runInit } = await import('./init.ts')
    const options = parseInitArgs(rest)
    const result = await runInit(options)
    console.log(`Created config: ${result.configPath}`)
    console.log(`Created features dir: ${result.featuresDir}`)
    break
  }

  case 'run': {
    const { parseRunArgs, runTests } = await import('./run.ts')
    const options = parseRunArgs(rest)
    const exitCode = await runTests(options)
    process.exit(exitCode)
    break
  }

  default:
    console.error(`Unknown command: ${subcommand ?? '(none)'}`)
    console.error('Usage: exo-bdd <command> [options]')
    console.error('')
    console.error('Commands:')
    console.error('  init   Scaffold a new exo-bdd project config')
    console.error('  run    Run BDD tests with a config file')
    process.exit(1)
}
