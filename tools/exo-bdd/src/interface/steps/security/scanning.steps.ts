import { When, Given } from '@cucumber/cucumber'
import { TestWorld } from '../../world/index.ts'

export interface ScanningContext {
  security: TestWorld['security']
  interpolate: TestWorld['interpolate']
  setVariable: TestWorld['setVariable']
}

// Session Management
export async function newZapSession(context: ScanningContext): Promise<void> {
  await context.security.newSession()
}

// Spidering
export async function spiderUrl(context: ScanningContext, url: string): Promise<void> {
  const result = await context.security.spider(context.interpolate(url))
  context.setVariable('_spiderResult', result)
}

export async function ajaxSpiderUrl(context: ScanningContext, url: string): Promise<void> {
  const result = await context.security.ajaxSpider(context.interpolate(url))
  context.setVariable('_spiderResult', result)
}

// Scanning
export async function runPassiveScan(context: ScanningContext, url: string): Promise<void> {
  const result = await context.security.passiveScan(context.interpolate(url))
  context.setVariable('_scanResult', result)
}

export async function runActiveScan(context: ScanningContext, url: string): Promise<void> {
  const result = await context.security.activeScan(context.interpolate(url))
  context.setVariable('_scanResult', result)
}

export async function runBaselineScan(context: ScanningContext, url: string): Promise<void> {
  // A baseline scan is spider + passive scan
  await context.security.spider(context.interpolate(url))
  const result = await context.security.passiveScan(context.interpolate(url))
  context.setVariable('_scanResult', result)
}

// Security Headers
export async function checkSecurityHeaders(context: ScanningContext, url: string): Promise<void> {
  const result = await context.security.checkSecurityHeaders(context.interpolate(url))
  context.setVariable('_headerCheckResult', result)
}

// SSL Certificate
export async function checkSslCertificate(context: ScanningContext, url: string): Promise<void> {
  const result = await context.security.checkSslCertificate(context.interpolate(url))
  context.setVariable('_sslCheckResult', result)
}

// Reporting
export async function saveSecurityReportHtml(context: ScanningContext, outputPath: string): Promise<void> {
  await context.security.generateHtmlReport(context.interpolate(outputPath))
}

export async function saveSecurityReportJson(context: ScanningContext, outputPath: string): Promise<void> {
  await context.security.generateJsonReport(context.interpolate(outputPath))
}

// Cucumber Registrations
Given<TestWorld>('a new ZAP session', async function () {
  await newZapSession(this)
})

When<TestWorld>('I spider {string}', async function (url: string) {
  await spiderUrl(this, url)
})

When<TestWorld>('I ajax spider {string}', async function (url: string) {
  await ajaxSpiderUrl(this, url)
})

When<TestWorld>('I run a passive scan on {string}', async function (url: string) {
  await runPassiveScan(this, url)
})

When<TestWorld>('I run an active scan on {string}', async function (url: string) {
  await runActiveScan(this, url)
})

When<TestWorld>('I run a baseline scan on {string}', async function (url: string) {
  await runBaselineScan(this, url)
})

When<TestWorld>('I check {string} for security headers', async function (url: string) {
  await checkSecurityHeaders(this, url)
})

When<TestWorld>('I check SSL certificate for {string}', async function (url: string) {
  await checkSslCertificate(this, url)
})

When<TestWorld>('I save the security report to {string}', async function (outputPath: string) {
  await saveSecurityReportHtml(this, outputPath)
})

When<TestWorld>('I save the security report as JSON to {string}', async function (outputPath: string) {
  await saveSecurityReportJson(this, outputPath)
})
