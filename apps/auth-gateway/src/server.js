import 'dotenv/config';
import cors from 'cors';
import express from 'express';
import { fromNodeHeaders, toNodeHandler } from 'better-auth/node';
import { auth, closeAuthDatabase } from './auth.js';
import { parseList, requiredEnv } from './env.js';

const app = express();
const port = Number(process.env.PORT || 3005);
const lafApiUrl = process.env.LAF_API_URL || 'https://sdswgya641.sealoshzh.site/paperbanana-api';
const gatewayToken = process.env.PAPERBANANA_GATEWAY_TOKEN || '';
const allowedOrigins = new Set(
  parseList(
    process.env.FRONTEND_ORIGINS ||
      'http://localhost:5173,http://127.0.0.1:5173,https://www.paperbanana.asia,https://paperbanana.asia',
  ),
);

requiredEnv('BETTER_AUTH_SECRET');

app.set('trust proxy', true);

app.use(
  cors({
    origin(origin, callback) {
      if (!origin || allowedOrigins.has(origin)) {
        callback(null, true);
        return;
      }
      callback(new Error(`Origin not allowed: ${origin}`));
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-Admin-Token'],
  }),
);

// Better Auth must run before express.json(), otherwise its client requests can hang.
app.all('/api/auth/*', toNodeHandler(auth));

app.use(express.json({ limit: '1mb' }));

app.get('/health', async (_req, res) => {
  const laf = await callLaf({ action: 'health' }).catch((error) => ({
    code: 503,
    error: error.message,
  }));
  res.json({
    code: 0,
    ok: true,
    runtime: 'gateway',
    auth: 'better-auth',
    laf,
  });
});

app.get('/paperbanana-api', async (_req, res) => {
  const laf = await callLaf({ action: 'health' });
  res.json({
    code: 0,
    ok: true,
    runtime: 'gateway',
    auth: 'better-auth',
    laf,
  });
});

app.post('/paperbanana-api', async (req, res) => {
  const action = req.body?.action || 'health';

  try {
    if (action === 'health') {
      const laf = await callLaf({ action: 'health' });
      return res.json({ code: 0, ok: true, runtime: 'gateway', auth: 'better-auth', laf });
    }

    if (action === 'adminJobs' || action === 'initDatabase') {
      const data = await callLaf(withGatewayToken(req.body));
      return sendLafResponse(res, data);
    }

    if (action === 'createJob') {
      const session = await optionalSession(req);
      const data = await callLaf(
        withGatewayToken({
          ...req.body,
          userId: session?.user?.id || '',
          userEmail: session?.user?.email || '',
        }),
      );
      return sendLafResponse(res, data);
    }

    if (action === 'getJob') {
      const session = await optionalSession(req);
      const data = await callLaf(withGatewayToken(req.body));
      const ownerId = data?.job?.userId || data?.job?.user_id || '';
      if (ownerId && ownerId !== session?.user?.id) {
        return res.status(403).json({ code: 403, error: 'Forbidden' });
      }
      return sendLafResponse(res, data);
    }

    if (action === 'myJobs') {
      const session = await requireSession(req);
      const data = await callLaf(
        withGatewayToken({
          action: 'userJobs',
          userId: session.user.id,
          limit: req.body?.limit || 50,
        }),
      );
      return sendLafResponse(res, data);
    }

    return res.status(400).json({ code: 400, error: `Unknown gateway action: ${action}` });
  } catch (error) {
    const status = Number(error.status || error.statusCode || 500);
    return res.status(status).json({ code: status, error: error.message || String(error) });
  }
});

app.listen(port, () => {
  console.log(`PaperBanana auth gateway listening on ${port}`);
});

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

async function shutdown() {
  await closeAuthDatabase().catch(() => {});
  process.exit(0);
}

async function requireSession(req) {
  const session = await optionalSession(req);
  if (!session?.user) {
    const error = new Error('请先登录后再使用任务记录。');
    error.status = 401;
    throw error;
  }
  return session;
}

async function optionalSession(req) {
  const session = await auth.api.getSession({
    headers: fromNodeHeaders(req.headers),
  });
  return session;
}

async function callLaf(body) {
  const response = await fetch(lafApiUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const text = await response.text();
  let data = {};
  try {
    data = text ? JSON.parse(text) : {};
  } catch {
    data = { code: response.status, error: text || `HTTP ${response.status}` };
  }
  if (!response.ok) {
    throw new Error(data.error || data.detail || `Laf HTTP ${response.status}`);
  }
  return data;
}

function sendLafResponse(res, data) {
  const code = Number(data?.code || 0);
  if (code && code !== 0) {
    return res.status(code).json(data);
  }
  return res.json(data);
}

function withGatewayToken(body) {
  if (!gatewayToken) return body;
  return {
    ...body,
    gatewayToken,
  };
}
