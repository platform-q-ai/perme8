import { World, type IWorldOptions } from '@cucumber/cucumber'
import type { HttpPort, BrowserPort, CliPort, GraphPort, SecurityPort } from '../../application/ports/index.ts'
import { AdapterNotConfiguredError } from '../../domain/errors/index.ts'
import { VariableService } from '../../application/services/VariableService.ts'
import { InterpolationService } from '../../application/services/InterpolationService.ts'

export class TestWorld extends World {
  // Adapters (attached in Before hook via setters)
  private _http?: HttpPort
  private _browser?: BrowserPort
  private _cli?: CliPort
  private _graph?: GraphPort
  private _security?: SecurityPort

  get http(): HttpPort {
    if (!this._http) throw new AdapterNotConfiguredError('http')
    return this._http
  }
  set http(value: HttpPort) {
    this._http = value
  }

  get browser(): BrowserPort {
    if (!this._browser) throw new AdapterNotConfiguredError('browser')
    return this._browser
  }
  set browser(value: BrowserPort) {
    this._browser = value
  }

  get cli(): CliPort {
    if (!this._cli) throw new AdapterNotConfiguredError('cli')
    return this._cli
  }
  set cli(value: CliPort) {
    this._cli = value
  }

  get graph(): GraphPort {
    if (!this._graph) throw new AdapterNotConfiguredError('graph')
    return this._graph
  }
  set graph(value: GraphPort) {
    this._graph = value
  }

  get security(): SecurityPort {
    if (!this._security) throw new AdapterNotConfiguredError('security')
    return this._security
  }
  set security(value: SecurityPort) {
    this._security = value
  }

  // Shared state
  variables: Map<string, unknown> = new Map()

  // Services
  private variableService = new VariableService()
  private interpolationService = new InterpolationService(this.variableService)

  constructor(options: IWorldOptions) {
    super(options)
  }

  setVariable(name: string, value: unknown): void {
    this.variableService.set(name, value)
  }

  getVariable<T>(name: string): T {
    return this.variableService.get<T>(name)
  }

  hasVariable(name: string): boolean {
    return this.variableService.has(name)
  }

  interpolate(text: string): string {
    return this.interpolationService.interpolate(text)
  }

  reset(): void {
    this.variableService.clear()
  }
}
