import { createServer } from 'node:http';
import { open, readFile, stat } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { extname, join, normalize } from 'node:path';
import process from 'node:process';
import { URL } from 'node:url';
import net from 'node:net';

const rootDir = process.env.ROOT_DIR ?? normalize(join(process.cwd(), '..'));
const localHome = process.env.LOCAL_HOME ?? join(rootDir, 'local');
const runDir = process.env.RUN_DIR ?? join(localHome, 'run');
const logDir = process.env.LOG_DIR ?? join(localHome, 'logs');
const publicDir = join(localHome, 'ui', 'public');
const host = process.env.LOCAL_UI_HOST ?? '127.0.0.1';
const port = Number(process.env.LOCAL_UI_PORT ?? '3400');

const jsonHeaders = {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
};

const staticContentTypes = {
    '.html': 'text/html; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.json': 'application/json; charset=utf-8',
};

const serviceDefinitions = [
    {
        id: 'mariadb',
        name: 'MariaDB',
        group: 'infra',
        pidFiles: ['mysqld.pid'],
        port: 3306,
        logFiles: ['mariadb.stdout', 'mariadb.err'],
    },
    {
        id: 'valkey',
        name: 'Valkey',
        group: 'infra',
        pidFiles: ['valkey.pid'],
        port: 6379,
        logFiles: ['valkey.log'],
    },
    {
        id: 'kafka',
        name: 'Kafka',
        group: 'infra',
        pidFiles: ['kafka.pid'],
        port: 9092,
        logFiles: ['kafka.log', 'server.log'],
    },
    {
        id: 'nats',
        name: 'NATS',
        group: 'infra',
        pidFiles: ['nats.pid'],
        port: 4222,
        healthUrl: 'http://127.0.0.1:8222/healthz',
        logFiles: ['nats.log'],
    },
    {
        id: 'central-ledger-api',
        name: 'Central Ledger',
        group: 'core',
        pidFiles: ['services/central-ledger-api.pid'],
        port: 3001,
        healthUrl: 'http://127.0.0.1:3001/health',
        logFiles: ['central-ledger-api.log'],
    },
    {
        id: 'ml-api-adapter-api',
        name: 'ML API Adapter',
        group: 'core',
        pidFiles: ['services/ml-api-adapter-api.pid'],
        port: 3000,
        healthUrl: 'http://127.0.0.1:3000/health',
        logFiles: ['ml-api-adapter-api.log'],
    },
    {
        id: 'account-lookup-api',
        name: 'ALS API',
        group: 'core',
        pidFiles: ['services/account-lookup-api.pid'],
        port: 4002,
        healthUrl: 'http://127.0.0.1:4002/health',
        logFiles: ['account-lookup-api.log'],
    },
    {
        id: 'account-lookup-admin',
        name: 'ALS Admin',
        group: 'core',
        pidFiles: ['services/account-lookup-admin.pid'],
        port: 4001,
        healthUrl: 'http://127.0.0.1:4001/health',
        logFiles: ['account-lookup-admin.log'],
    },
    {
        id: 'account-lookup-handlers',
        name: 'ALS Handlers',
        group: 'core',
        pidFiles: ['services/account-lookup-handlers.pid'],
        port: 4003,
        healthUrl: 'http://127.0.0.1:4003/health',
        logFiles: ['account-lookup-handlers.log'],
    },
    {
        id: 'quoting-api',
        name: 'Quoting API',
        group: 'core',
        pidFiles: ['services/quoting-api.pid'],
        port: 3002,
        healthUrl: 'http://127.0.0.1:3002/health',
        logFiles: ['quoting-api.log'],
    },
    {
        id: 'quoting-handlers',
        name: 'Quoting Handlers',
        group: 'core',
        pidFiles: ['services/quoting-handlers.pid'],
        port: 3103,
        healthUrl: 'http://127.0.0.1:3103/health',
        logFiles: ['quoting-handlers.log'],
    },
    {
        id: 'central-settlement-api',
        name: 'Central Settlement',
        group: 'core',
        pidFiles: ['services/central-settlement-api.pid'],
        port: 3007,
        healthUrl: 'http://127.0.0.1:3007/v2/health',
        logFiles: ['central-settlement-api.log'],
    },
    {
        id: 'pivotal-web-outbound',
        name: 'Pivotal Web Outbound',
        group: 'wallet',
        pidFiles: ['wallet1-web-outbound.pid', 'wallet2-web-outbound.pid'],
        port: 3200,
        logFiles: ['wallet1-web-outbound.log', 'wallet2-web-outbound.log'],
    },
    {
        id: 'pivotal-app-auditor',
        name: 'Pivotal App Auditor',
        group: 'wallet',
        pidFiles: ['pivotal-app-auditor.pid'],
        logFiles: ['pivotal-app-auditor.log'],
    },
    {
        id: 'pivotal-web-pivotal',
        name: 'Pivotal Portal API',
        group: 'wallet',
        pidFiles: ['pivotal-web-pivotal.pid'],
        port: 3202,
        logFiles: ['pivotal-web-pivotal.log'],
    },
    {
        id: 'pivotal-portal',
        name: 'Pivotal Portal UI',
        group: 'wallet',
        pidFiles: ['pivotal-portal.pid'],
        port: 4173,
        healthUrl: 'http://127.0.0.1:4173/',
        logFiles: ['pivotal-portal.log'],
    },
    {
        id: 'pivotal-web-inbound',
        name: 'Pivotal Web Inbound',
        group: 'wallet',
        pidFiles: ['wallet1-web-inbound.pid', 'wallet2-web-inbound.pid'],
        port: 3201,
        logFiles: ['wallet1-web-inbound.log', 'wallet2-web-inbound.log'],
    },
    {
        id: 'wallet1-connector',
        name: 'Wallet1 Pivotal Connector',
        group: 'wallet',
        pidFiles: ['wallet1-pivotal-connector.pid'],
        logFiles: ['wallet1-pivotal-connector.log'],
    },
    {
        id: 'wallet2-connector',
        name: 'Wallet2 Pivotal Connector',
        group: 'wallet',
        pidFiles: ['wallet2-pivotal-connector.pid'],
        logFiles: ['wallet2-pivotal-connector.log'],
    },
    {
        id: 'wallet1-demowallet',
        name: 'Wallet1 DemoWallet Backend',
        group: 'wallet',
        pidFiles: ['wallet1-demowallet.pid'],
        port: 8081,
        healthUrl: 'http://127.0.0.1:8081/public/heart_beat',
        logFiles: ['wallet1-demowallet.log'],
    },
    {
        id: 'wallet2-demowallet',
        name: 'Wallet2 DemoWallet Backend',
        group: 'wallet',
        pidFiles: ['wallet2-demowallet.pid'],
        port: 8082,
        healthUrl: 'http://127.0.0.1:8082/public/heart_beat',
        logFiles: ['wallet2-demowallet.log'],
    },
];

const serviceMap = new Map(serviceDefinitions.map((service) => [service.id, service]));

const fileExists = (filePath) => filePath != null && existsSync(filePath);

const resolveRunPath = (relativePath) => join(runDir, relativePath);
const resolveLogPath = (relativePath) => join(logDir, relativePath);

const resolveFirstExistingPath = (baseResolver, candidates = []) => {
    for (const candidate of candidates) {
        const fullPath = baseResolver(candidate);
        if (fileExists(fullPath)) {
            return fullPath;
        }
    }

    return candidates.length > 0 ? baseResolver(candidates[0]) : null;
};

const readTextFile = async (filePath) => {
    try {
        return await readFile(filePath, 'utf8');
    } catch {
        return null;
    }
};

const readPidFromFile = async (relativePath) => {
    const pidText = await readTextFile(resolveRunPath(relativePath));
    const pid = pidText?.match(/\d+/)?.[0];

    return pid != null ? Number(pid) : null;
};

const processRunning = (pid) => {
    if (pid == null) {
        return false;
    }

    try {
        process.kill(pid, 0);
        return true;
    } catch {
        return false;
    }
};

const checkPort = async (targetPort) => new Promise((resolve) => {
    const socket = net.createConnection({ host: '127.0.0.1', port: targetPort });

    const finish = (result) => {
        socket.removeAllListeners();
        socket.destroy();
        resolve(result);
    };

    socket.setTimeout(700);
    socket.once('connect', () => finish(true));
    socket.once('timeout', () => finish(false));
    socket.once('error', () => finish(false));
});

const healthFromPayload = async (healthUrl) => {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 1500);

    try {
        const response = await fetch(healthUrl, {
            signal: controller.signal,
            headers: {
                Accept: 'application/json, text/plain;q=0.9, */*;q=0.8',
            },
        });

        const bodyText = await response.text();
        const trimmed = bodyText.trim();
        let detail = trimmed;

        if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
            try {
                const parsed = JSON.parse(trimmed);
                detail = typeof parsed?.status === 'string'
                    ? parsed.status
                    : trimmed;
            } catch {
                detail = trimmed;
            }
        }

        return {
            state: response.ok ? 'ok' : 'error',
            statusCode: response.status,
            detail,
        };
    } catch (error) {
        return {
            state: 'error',
            statusCode: null,
            detail: error instanceof Error ? error.message : String(error),
        };
    } finally {
        clearTimeout(timeout);
    }
};

const resolvePid = async (service) => {
    for (const relativePath of service.pidFiles ?? []) {
        const pid = await readPidFromFile(relativePath);
        if (processRunning(pid)) {
            return pid;
        }
    }

    return null;
};

const resolveLog = (service) => {
    const logPath = resolveFirstExistingPath(resolveLogPath, service.logFiles);

    if (logPath == null) {
        return {
            path: null,
            exists: false,
        };
    }

    return {
        path: logPath,
        exists: fileExists(logPath),
    };
};

const summarizeService = async (service) => {
    const pid = await resolvePid(service);
    const portOpen = service.port != null ? await checkPort(service.port) : false;
    const health = service.healthUrl != null
        ? await healthFromPayload(service.healthUrl)
        : {
            state: service.port != null
                ? (portOpen ? 'port-open' : 'unknown')
                : (pid != null ? 'pid-only' : 'unknown'),
            statusCode: null,
            detail: service.healthUrl ?? '',
        };

    const log = resolveLog(service);
    const running = pid != null || portOpen || health.state === 'ok';

    return {
        id: service.id,
        name: service.name,
        group: service.group,
        running,
        pid,
        port: service.port ?? null,
        healthUrl: service.healthUrl ?? null,
        health,
        log,
    };
};

const statusPayload = async () => {
    const services = await Promise.all(serviceDefinitions.map((service) => summarizeService(service)));
    const totals = services.reduce((summary, service) => {
        summary.total += 1;
        if (service.running) {
            summary.running += 1;
        } else {
            summary.stopped += 1;
        }
        if (service.health.state === 'error') {
            summary.unhealthy += 1;
        }
        return summary;
    }, { total: 0, running: 0, stopped: 0, unhealthy: 0 });

    return {
        generatedAt: new Date().toISOString(),
        totals,
        services,
    };
};

const tailFile = async (filePath, requestedLines) => {
    const lines = Math.max(20, Math.min(1000, Number(requestedLines) || 200));

    if (!fileExists(filePath)) {
        return {
            exists: false,
            path: filePath,
            text: '',
            lines,
            truncated: false,
            updatedAt: null,
            size: 0,
        };
    }

    const metadata = await stat(filePath);
    const readSize = Math.min(metadata.size, 256 * 1024);
    const start = Math.max(0, metadata.size - readSize);
    const handle = await open(filePath, 'r');

    try {
        const buffer = Buffer.alloc(readSize);
        const { bytesRead } = await handle.read(buffer, 0, readSize, start);
        const chunk = buffer.toString('utf8', 0, bytesRead);
        const allLines = chunk.split('\n');
        const selected = allLines.slice(-lines);

        return {
            exists: true,
            path: filePath,
            text: selected.join('\n'),
            lines,
            truncated: start > 0,
            updatedAt: metadata.mtime.toISOString(),
            size: metadata.size,
        };
    } finally {
        await handle.close();
    }
};

const writeJson = (response, statusCode, payload) => {
    response.writeHead(statusCode, jsonHeaders);
    response.end(JSON.stringify(payload));
};

const serveStatic = async (requestPath, response) => {
    const target = requestPath === '/' ? '/index.html' : requestPath;
    const normalized = normalize(target)
        .replace(/^[/\\]+/, '')
        .replace(/^(\.\.[/\\])+/, '');
    const filePath = join(publicDir, normalized);

    if (!filePath.startsWith(publicDir)) {
        response.writeHead(403);
        response.end('Forbidden');
        return;
    }

    try {
        const content = await readFile(filePath);
        response.writeHead(200, {
            'Content-Type': staticContentTypes[extname(filePath)] ?? 'application/octet-stream',
            'Cache-Control': 'no-store',
        });
        response.end(content);
    } catch {
        response.writeHead(404);
        response.end('Not found');
    }
};

const server = createServer(async (request, response) => {
    const requestUrl = new URL(request.url ?? '/', `http://${host}:${port}`);

    if (requestUrl.pathname === '/api/status') {
        writeJson(response, 200, await statusPayload());
        return;
    }

    if (requestUrl.pathname === '/api/logs') {
        const id = requestUrl.searchParams.get('id') ?? '';
        const service = serviceMap.get(id);

        if (service == null) {
            writeJson(response, 404, { error: `Unknown service "${id}"` });
            return;
        }

        const log = resolveLog(service);
        writeJson(response, 200, await tailFile(log.path, requestUrl.searchParams.get('lines')));
        return;
    }

    if (request.method !== 'GET') {
        response.writeHead(405);
        response.end('Method not allowed');
        return;
    }

    await serveStatic(requestUrl.pathname, response);
});

server.listen(port, host, () => {
    process.stdout.write(`Local UI listening on http://${host}:${port}\n`);
});
