#!/usr/bin/env node
'use strict'

const http = require('node:http')
const https = require('node:https')
const { URL } = require('node:url')

const listenPort = Number.parseInt(process.env.DELAY_PROXY_PORT || '3299', 10)
const targetBase = new URL(process.env.DELAY_PROXY_TARGET || 'http://127.0.0.1:3201')
const delayMs = Number.parseInt(process.env.DELAY_PROXY_DELAY_MS || '17000', 10)
const delayMethod = (process.env.DELAY_PROXY_METHOD || 'POST').toUpperCase()
const delayPath = process.env.DELAY_PROXY_PATH || '/transfers'
const targetTimeoutMs = Number.parseInt(process.env.DELAY_PROXY_TARGET_TIMEOUT_MS || '30000', 10)

const log = (entry) => {
  process.stdout.write(`${JSON.stringify({ ts: new Date().toISOString(), ...entry })}\n`)
}

const server = http.createServer((request, response) => {
  const chunks = []
  const startedAt = Date.now()

  request.on('data', (chunk) => chunks.push(chunk))
  request.on('error', (error) => {
    log({ event: 'request-error', message: error.message })
    if (!response.headersSent) {
      response.writeHead(502, { 'content-type': 'application/json' })
    }
    response.end(JSON.stringify({ error: error.message }))
  })
  request.on('end', () => {
    const body = Buffer.concat(chunks)
    const requestUrl = new URL(request.url || '/', 'http://localhost')
    const shouldDelay = request.method?.toUpperCase() === delayMethod && requestUrl.pathname === delayPath
    const waitMs = shouldDelay ? delayMs : 0

    log({
      event: 'received',
      method: request.method,
      path: requestUrl.pathname,
      delayMs: waitMs,
      target: new URL(request.url || '/', targetBase).toString()
    })

    setTimeout(() => forward(request, response, body, startedAt), waitMs)
  })
})

const forward = (incomingRequest, outgoingResponse, body, startedAt) => {
  const targetUrl = new URL(incomingRequest.url || '/', targetBase)
  const headers = { ...incomingRequest.headers }
  delete headers.connection
  delete headers['transfer-encoding']
  headers.host = targetUrl.host
  headers['content-length'] = String(body.length)

  const client = targetUrl.protocol === 'https:' ? https : http
  const proxyRequest = client.request({
    protocol: targetUrl.protocol,
    hostname: targetUrl.hostname,
    port: targetUrl.port,
    method: incomingRequest.method,
    path: `${targetUrl.pathname}${targetUrl.search}`,
    headers,
    timeout: targetTimeoutMs
  }, (proxyResponse) => {
    outgoingResponse.writeHead(proxyResponse.statusCode || 502, proxyResponse.headers)
    proxyResponse.pipe(outgoingResponse)
    proxyResponse.on('end', () => {
      log({
        event: 'forwarded',
        method: incomingRequest.method,
        path: targetUrl.pathname,
        statusCode: proxyResponse.statusCode,
        durationMs: Date.now() - startedAt
      })
    })
  })

  proxyRequest.on('timeout', () => {
    proxyRequest.destroy(new Error(`Target timed out after ${targetTimeoutMs}ms`))
  })

  proxyRequest.on('error', (error) => {
    log({
      event: 'forward-error',
      method: incomingRequest.method,
      path: targetUrl.pathname,
      message: error.message,
      durationMs: Date.now() - startedAt
    })
    if (!outgoingResponse.headersSent) {
      outgoingResponse.writeHead(502, { 'content-type': 'application/json' })
    }
    outgoingResponse.end(JSON.stringify({ error: error.message }))
  })

  proxyRequest.end(body)
}

server.listen(listenPort, '127.0.0.1', () => {
  log({
    event: 'listening',
    port: listenPort,
    target: targetBase.toString(),
    delayMethod,
    delayPath,
    delayMs
  })
})
