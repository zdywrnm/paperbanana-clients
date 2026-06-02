import 'dotenv/config';
import { betterAuth } from 'better-auth';
import { mongodbAdapter } from 'better-auth/adapters/mongodb';
import { MongoClient } from 'mongodb';
import { isProduction, parseList, requiredEnv } from './env.js';

const mongoUri = requiredEnv('MONGODB_URI');
const authSecret = requiredEnv('BETTER_AUTH_SECRET');
const mongoDbName = process.env.MONGODB_DB || 'paperbanana';
const authBaseUrl = process.env.AUTH_BASE_URL || 'http://localhost:3005';
const trustedOrigins = parseList(
  process.env.FRONTEND_ORIGINS ||
    'http://localhost:5173,http://127.0.0.1:5173,https://www.paperbanana.asia,https://paperbanana.asia',
);
const cookieDomain = process.env.COOKIE_DOMAIN || '';
const cookieSameSite = (process.env.COOKIE_SAME_SITE || '').toLowerCase();

export const mongoClient = new MongoClient(mongoUri);
await mongoClient.connect();
export const authDb = mongoClient.db(mongoDbName);

const advanced = {
  useSecureCookies: isProduction(),
  cookiePrefix: 'paperbanana',
};

if (cookieDomain) {
  advanced.crossSubDomainCookies = {
    enabled: true,
    domain: cookieDomain,
  };
}

if (['lax', 'strict', 'none'].includes(cookieSameSite)) {
  advanced.defaultCookieAttributes = {
    sameSite: cookieSameSite,
  };
}

export const auth = betterAuth({
  appName: 'PaperBanana',
  secret: authSecret,
  baseURL: authBaseUrl,
  trustedOrigins,
  database: mongodbAdapter(authDb),
  emailAndPassword: {
    enabled: true,
    requireEmailVerification: false,
  },
  advanced,
});

export async function closeAuthDatabase() {
  await mongoClient.close();
}
