import 'dotenv/config';
import cors from 'cors';
import express from 'express';
import { fromNodeHeaders, toNodeHandler } from 'better-auth/node';
import { auth, authDb, closeAuthDatabase } from './auth.js';
import { parseList, requiredEnv } from './env.js';

const app = express();
const port = Number(process.env.PORT || 3005);
const lafApiUrl = process.env.LAF_API_URL || 'https://sdswgya641.sealoshzh.site/paperbanana-api';
const gatewayToken = process.env.PAPERBANANA_GATEWAY_TOKEN || '';
const adminToken = process.env.ADMIN_TOKEN || '';
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

    if (action === 'adminJobs' || action === 'adminFeedback' || action === 'initDatabase') {
      const data = await callLaf(withGatewayToken(req.body), req);
      return sendLafResponse(res, data);
    }

    if (action === 'prepareReferenceUpload') {
      const session = await optionalSession(req);
      const data = await callLaf(
        withGatewayToken({
          ...req.body,
          userId: session?.user?.id || '',
          userEmail: session?.user?.email || '',
        }),
        req,
      );
      return sendLafResponse(res, data);
    }

    if (action === 'modelCapability') {
      const data = await callLaf(withGatewayToken(req.body), req);
      return sendLafResponse(res, data);
    }

    if (action === 'adminUsers') {
      requireAdminToken(req.body?.adminToken);
      const data = await listAuthUsers(req.body);
      return res.json({ code: 0, ...data });
    }

    if (action === 'submitFeedback') {
      const session = await optionalSession(req);
      const data = await callLaf(
        withGatewayToken({
          ...normalizeFeedbackBody(req.body),
          userId: session?.user?.id || '',
          userEmail: session?.user?.email || '',
        }),
        req,
      );
      return sendLafResponse(res, data);
    }

    if (action === 'createJob') {
      const session = await optionalSession(req);
      const jobBody = normalizeCreateJobBody(req.body);
      const data = await callLaf(
        withGatewayToken({
          ...jobBody,
          userId: session?.user?.id || '',
          userEmail: session?.user?.email || '',
        }),
        req,
      );
      return sendLafResponse(res, data);
    }

    if (action === 'getJob') {
      const session = await optionalSession(req);
      const data = await callLaf(withGatewayToken(req.body), req);
      const ownerId = data?.job?.userId || data?.job?.user_id || '';
      const isAdmin = isValidAdminToken(req.body?.adminToken);
      if (ownerId && !isAdmin && ownerId !== session?.user?.id) {
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
        req,
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

async function callLaf(body, req) {
  const response = await fetch(lafApiUrl, {
    method: 'POST',
    headers: lafHeaders(req),
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

function lafHeaders(req) {
  const headers = { 'Content-Type': 'application/json' };
  if (!req) return headers;

  const forwarded = headerValue(req.headers['x-forwarded-for']) || req.ip || req.socket?.remoteAddress || '';
  const realIp = headerValue(req.headers['x-real-ip']) || req.ip || '';
  const userAgent = headerValue(req.headers['user-agent']);
  if (forwarded) headers['X-Forwarded-For'] = forwarded;
  if (realIp) headers['X-Real-IP'] = realIp;
  if (userAgent) headers['User-Agent'] = userAgent;
  return headers;
}

function headerValue(value) {
  if (Array.isArray(value)) return value.filter(Boolean).join(',');
  return value || '';
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

function normalizeCreateJobBody(body) {
  return {
    ...body,
    mainModelName: normalizeModelName(body?.provider, body?.mainModelName),
    imageModelName: normalizeModelName(body?.provider, body?.imageModelName),
  };
}

function normalizeFeedbackBody(body) {
  return {
    action: 'submitFeedback',
    message: body?.message,
    category: body?.category,
    jobId: body?.jobId,
    platform: body?.platform,
    clientVersion: body?.clientVersion,
    contact: body?.contact,
  };
}

function normalizeModelName(provider, model) {
  if (provider === 'gemini' && model === 'gemini-3.1-flash-image-preview') {
    return 'gemini-3.1-flash-image';
  }
  return model;
}

function requireAdminToken(token) {
  if (!adminToken) {
    const error = new Error('Admin API disabled: ADMIN_TOKEN is not configured');
    error.status = 503;
    throw error;
  }
  if (token !== adminToken) {
    const error = new Error('Invalid admin token');
    error.status = 401;
    throw error;
  }
}

function isValidAdminToken(token) {
  return Boolean(adminToken && token === adminToken);
}

async function listAuthUsers(body = {}) {
  const limit = clamp(Number(body.limit || 100), 1, 500);
  const users = await authDb
    .collection('user')
    .find({})
    .sort({ createdAt: -1, _id: -1 })
    .limit(limit)
    .toArray();

  const userIds = users.map((user) => user._id).filter(Boolean);
  const userIdStrings = userIds.map((id) => String(id));
  const sessionLookup = await latestSessionsByUser(userIds, userIdStrings);

  return {
    users: users.map((user) => publicAuthUser(user, sessionLookup.get(String(user._id)))),
  };
}

async function latestSessionsByUser(userIds, userIdStrings) {
  if (!userIds.length) return new Map();
  const rows = await authDb
    .collection('session')
    .aggregate([
      {
        $match: {
          $or: [
            { userId: { $in: userIds } },
            { userId: { $in: userIdStrings } },
          ],
        },
      },
      { $sort: { updatedAt: -1, createdAt: -1, _id: -1 } },
      {
        $group: {
          _id: '$userId',
          sessionCount: { $sum: 1 },
          latestSessionAt: { $first: { $ifNull: ['$updatedAt', '$createdAt'] } },
          lastIpAddress: { $first: '$ipAddress' },
          lastUserAgent: { $first: '$userAgent' },
        },
      },
    ])
    .toArray();
  return new Map(rows.map((row) => [String(row._id), row]));
}

function publicAuthUser(user, session) {
  return {
    id: String(user._id || user.id || ''),
    email: user.email || '',
    name: user.name || '',
    emailVerified: Boolean(user.emailVerified),
    image: user.image || '',
    createdAt: user.createdAt || '',
    updatedAt: user.updatedAt || '',
    lastLoginAt: session?.latestSessionAt || '',
    sessionCount: Number(session?.sessionCount || 0),
    lastIpAddress: session?.lastIpAddress || '',
    lastUserAgent: session?.lastUserAgent || '',
  };
}

function clamp(value, min, max) {
  if (Number.isNaN(value)) return min;
  return Math.max(min, Math.min(value, max));
}
