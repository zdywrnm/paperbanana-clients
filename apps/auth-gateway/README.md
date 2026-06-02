# PaperBanana Auth Gateway

This app contains the Node.js gateway deployed on Sealos for PaperBanana account login and authenticated task-record access.

## Responsibilities

- Serve Better Auth email/password APIs under `/api/auth/*`.
- Store users, accounts, and sessions in MongoDB through Better Auth.
- Proxy PaperBanana job requests to the Laf function at `/paperbanana-api`.
- Attach the logged-in user's `userId` and `userEmail` to `createJob` requests.
- Protect `myJobs` and owner-scoped `getJob` access.
- Expose an admin-only account list for registered/logged-in users.

## Production

- Sealos app: `paperbanana-auth-gateway`
- Runtime image: `node:22-alpine`
- Port: `3005`
- Current public URL: `https://yifbnnzrwmxn.sealoshzh.site`
- Laf API URL: `https://sdswgya641.sealoshzh.site/paperbanana-api`

## Environment

Copy `.env.example` and configure real values in Sealos. Do not commit real secrets.

Required variables:

- `AUTH_BASE_URL`: public URL of this gateway.
- `FRONTEND_ORIGINS`: comma-separated allowed frontend origins.
- `BETTER_AUTH_SECRET`: long random secret used by Better Auth.
- `MONGODB_URI`: MongoDB connection string.
- `MONGODB_DB`: MongoDB database name.
- `LAF_API_URL`: Laf function URL.
- `PAPERBANANA_GATEWAY_TOKEN`: shared token forwarded to Laf when direct public writes are restricted.
- `ADMIN_TOKEN`: shared owner token for the website admin panel.

## Local Development

From the repository root:

```bash
pnpm install
cp apps/auth-gateway/.env.example apps/auth-gateway/.env
pnpm --filter @paperbanana/auth-gateway dev
```

`dev` requires valid MongoDB and Better Auth environment variables.

Syntax check:

```bash
pnpm --filter @paperbanana/auth-gateway check
```

## Docker

Build from the repository root so the Dockerfile can use the workspace lockfile:

```bash
docker build -f apps/auth-gateway/Dockerfile -t paperbanana-auth-gateway .
```

For Sealos, keep the same environment variables as `.env.example` and expose port `3005`.

## GitHub Actions Image

The workflow `.github/workflows/build-auth-gateway.yml` builds and pushes this app to GitHub Container Registry:

```text
ghcr.io/zdywrnm/paperbanana-auth-gateway:latest
```

After the first successful workflow run, make the GHCR package public or configure Sealos with registry credentials. Then update the existing Sealos app image to the GHCR image above and redeploy.

## Notes

- This app does not store model API keys. User-provided model keys are forwarded only as part of the job request.
- `PAPERBANANA_GATEWAY_TOKEN` only blocks direct Laf writes if the Laf function also validates it.
- `adminUsers` returns only sanitized user profile and session summary fields; it does not expose passwords, session tokens, or auth account secrets.
- The archived Laf function source lives in `apps/laf-functions/`.
