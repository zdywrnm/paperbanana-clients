import 'dotenv/config';
import cors from 'cors';
import express from 'express';
import { ObjectId } from 'mongodb';
import { fromNodeHeaders, toNodeHandler } from 'better-auth/node';
import { auth, authDb, closeAuthDatabase } from './auth.js';
import { parseList, requiredEnv } from './env.js';

const app = express();
const port = Number(process.env.PORT || 3005);
const lafApiUrl = process.env.LAF_API_URL || 'https://sdswgya641.sealoshzh.site/paperbanana-api';
const gatewayToken = process.env.PAPERBANANA_GATEWAY_TOKEN || '';
const adminToken = process.env.ADMIN_TOKEN || '';
const adminEmails = new Set(parseList(process.env.ADMIN_EMAILS).map((email) => email.toLowerCase()));
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

// Account deletion (App Store guideline 5.1.1(v)).
// Flow:
//   1. Require a valid session and confirm it belongs to body.email.
//   2. Re-authenticate email+password via Better Auth (second confirmation).
//   3. Purge business data in Laf (deleteAccount) — done first so the user row
//      survives if it fails and the client can retry.
//   4. Hard delete the Better Auth user + all their sessions from Mongo so the
//      account can never log in again.
//   5. Clear the client session cookie and return { ok: true }.
app.post('/api/account/delete', async (req, res) => {
  try {
    const session = await requireSession(req);
    const sessionEmail = String(session.user.email || '').trim().toLowerCase();
    const requestedEmail = String(req.body?.email || '').trim().toLowerCase();
    const password = String(req.body?.password || '');

    if (!requestedEmail || !password) {
      return res.status(400).json({ code: 400, error: 'email and password are required' });
    }
    if (sessionEmail !== requestedEmail) {
      // The logged-in session does not own the account being deleted.
      return res.status(403).json({ code: 403, error: 'EMAIL_MISMATCH' });
    }

    // Step 2: second confirmation — re-verify the password. signInEmail throws
    // (Better Auth APIError) when the password is wrong. The email already maps
    // to the authenticated session, so a failure here means a bad password.
    try {
      await auth.api.signInEmail({
        body: { email: session.user.email, password },
        headers: fromNodeHeaders(req.headers),
      });
    } catch {
      return res.status(401).json({ code: 401, error: 'INVALID_PASSWORD' });
    }

    const userId = String(session.user.id || '');
    const userEmail = String(session.user.email || '');

    // Step 3: purge business data first. If Laf fails we stop here WITHOUT
    // deleting the auth user, so the still-valid session can retry. deleteAccount
    // is idempotent on the Laf side.
    await callLaf(
      withGatewayToken({ action: 'deleteAccount', userId, userEmail }),
      req,
    );

    // Step 4: clear the client session cookie while the session still exists, so
    // Better Auth's signOut reliably emits the cookie-clearing Set-Cookie header.
    await clearSessionCookie(req, res);

    // Step 5: hard delete the Better Auth user + every remaining session. Done
    // directly against the adapter's Mongo collections (the Better Auth
    // deleteUser API is not enabled and would trigger an email-confirmation flow
    // we must avoid). Idempotent, so it also mops up the just-signed-out session.
    await deleteAuthUser(userId);

    return res.json({ code: 0, ok: true });
  } catch (error) {
    const status = Number(error.status || error.statusCode || 500);
    return res.status(status).json({ code: status, error: error.message || String(error) });
  }
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

    if (action === 'adminStatus') {
      return res.json({ code: 0, isAdmin: await isAdminSession(req) });
    }

    if (action === 'adminJobs' || action === 'adminFeedback' || action === 'initDatabase') {
      await requireAdminSessionOrToken(req);
      const data = await callLaf(withGatewayToken(withInternalAdminToken(req.body)), req);
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

    if (action === 'referenceLibrary') {
      const data = await callLaf(withGatewayToken(req.body), req);
      return sendLafResponse(res, data);
    }

    if (action === 'adminUsers') {
      await requireAdminSessionOrToken(req);
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

    if (action === 'refineImage') {
      const session = await optionalSession(req);
      const data = await callLaf(
        withGatewayToken({
          ...req.body,
          mainModelName: normalizeModelName(req.body?.provider, req.body?.mainModelName),
          imageModelName: normalizeModelName(req.body?.provider, req.body?.imageModelName),
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
      const isAdmin = isAdminUser(session?.user) || isValidAdminToken(req.body?.adminToken);
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

async function requireAdminSessionOrToken(req) {
  const session = await optionalSession(req);
  if (isAdminUser(session?.user)) return session;
  if (isValidAdminToken(req.body?.adminToken)) return session;

  const error = new Error(session?.user ? 'Forbidden' : '请先登录管理员账号。');
  error.status = session?.user ? 403 : 401;
  throw error;
}

async function isAdminSession(req) {
  const session = await optionalSession(req);
  return isAdminUser(session?.user);
}

function isAdminUser(user) {
  const email = String(user?.email || '').trim().toLowerCase();
  return Boolean(email && adminEmails.has(email));
}

async function optionalSession(req) {
  const session = await auth.api.getSession({
    headers: fromNodeHeaders(req.headers),
  });
  return session;
}

// Hard delete a Better Auth user and all of their sessions from Mongo.
// Better Auth's mongo adapter stores user.id as the stringified _id ObjectId and
// session.userId may be stored as either an ObjectId or its string form (see
// latestSessionsByUser), so we match both shapes. Idempotent: re-running with an
// already-deleted id is a no-op.
async function deleteAuthUser(userId) {
  const id = String(userId || '');
  if (!id) return;

  const idCandidates = [id];
  let objectId = null;
  if (ObjectId.isValid(id)) {
    objectId = new ObjectId(id);
    idCandidates.push(objectId);
  }

  await authDb.collection('session').deleteMany({ userId: { $in: idCandidates } });
  await authDb.collection('account').deleteMany({ userId: { $in: idCandidates } }).catch(() => {});
  await authDb.collection('user').deleteOne(
    objectId ? { $or: [{ _id: objectId }, { id }] } : { $or: [{ _id: id }, { id }] },
  );
}

// Sign the current session out and relay Better Auth's own clearing Set-Cookie
// header to the client, so the cookie name, prefix and attributes always match
// this deployment's config. Best-effort: the user is deleted regardless.
async function clearSessionCookie(req, res) {
  try {
    const response = await auth.api.signOut({
      headers: fromNodeHeaders(req.headers),
      asResponse: true,
    });
    const setCookies =
      typeof response?.headers?.getSetCookie === 'function'
        ? response.headers.getSetCookie()
        : [];
    for (const cookie of setCookies) {
      res.append('Set-Cookie', cookie);
    }
  } catch {
    // Cookie clearing is best-effort; the account is already deleted.
  }
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

function withInternalAdminToken(body) {
  if (!adminToken) {
    const error = new Error('Admin API disabled: ADMIN_TOKEN is not configured');
    error.status = 503;
    throw error;
  }
  return {
    ...body,
    adminToken,
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
