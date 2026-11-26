# Orbita API (Fastify)

BFF for the Windows client: auth verify, conversations/messages, SSE chat stream, usage/quota, **Microsoft Store billing**, AI gateway (**xAI Grok only**).

## Run

```bash
cp ../../.env.example .env
# from repo root:
npm install
npm run dev:api
```

## Routes (MVP)

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| GET | `/health` | no | Liveness + config flags (`env`, `databaseConfigured`, `devStubAuth`, `msStoreConfigured`) |
| GET | `/health/ready` | no | Readiness: pings Postgres (503 when `DATABASE_URL` is set but unreachable) |
| GET | `/v1/me` | Bearer | Profile + `planTier` (Store override applied) |
| GET/POST | `/v1/conversations` | Bearer | List / create |
| GET | `/v1/conversations/:id` | Bearer | Conversation + messages |
| GET/POST | `/v1/conversations/:id/messages` | Bearer | History / append user msg |
| POST | `/v1/conversations/:id/messages/stream` | Bearer | SSE AI stream |
| GET | `/v1/usage` | Bearer | Message + token soft-cap |
| GET | `/v1/billing/store/products` | no | Store product catalog (Pro SKU) |
| POST | `/v1/billing/store/verify` | Bearer | Verify Store entitlement → sync `planTier` |
| GET | `/v1/billing/store/subscription` | Bearer | Current Store subscription snapshot |
| POST | `/v1/billing/checkout` | Bearer | **410** deprecated (was Stripe) |
| POST | `/v1/billing/portal` | Bearer | **410** deprecated (was Stripe) |
| POST | `/v1/billing/webhook` | — | **410** deprecated (was Stripe) |

Auth: `Authorization: Bearer <Supabase access token>`, verified with `SUPABASE_JWT_SECRET` (HS256) or the project JWKS
(ES256/RS256) plus issuer `${SUPABASE_URL}/auth/v1` and audience `authenticated`.
Dev only: with `ALLOW_DEV_STUB_AUTH=true` (ignored/forbidden when `NODE_ENV=production`), `Bearer stub:user_demo:free` or `stub:user_demo:pro` is accepted.

### Store verify body

```json
{
  "storeProductId": "pro_monthly",
  "userStoreId": "<User Store ID key from StoreContext>",
  "clientLicenseActive": true,
  "stubGrantPro": true
}
```

- With `MS_STORE_TENANT_ID` / `CLIENT_ID` / `CLIENT_SECRET`: Azure AD → Collections API query (client `stubGrantPro` ignored as source of truth).
- Without credentials and `NODE_ENV != production`: `stubGrantPro: true` grants Pro in-memory for local UX.
- Production without credentials: verify fails closed (`ms_store_not_configured`).

## AI gateway

- Free → `grok-fast` only → vendor `XAI_GROK_FAST_MODEL` (default `grok-4.3`, lighter/cheaper; reasoning off)
- Pro → `grok` (default) → vendor `XAI_GROK_MODEL` (default = recommended flagship stable, currently `grok-4.7`); or `grok-fast` when requested
- **Bump Pro flagship without code:** set `XAI_GROK_MODEL` (and usually `XAI_GROK_VISION_MODEL`) to the new stable id from [docs.x.ai/developers/models](https://docs.x.ai/developers/models), redeploy. xAI has no cross-family “always strongest” alias — family aliases only track within a family.
- Free and Pro do **not** share the same chat model
- With `XAI_API_KEY`: streams from xAI
- **Web search (default on):** xAI Responses API built-in `web_search` (`XAI_WEB_SEARCH_MODE=xai`) — automatic; only `XAI_API_KEY` required
- Fallback / local: `XAI_WEB_SEARCH_MODE=local` runs a `web_search` function-tool loop (DuckDuckGo free; optional `BRAVE_SEARCH_API_KEY`)
- Disable: `XAI_WEB_SEARCH_MODE=off`
- Web search counts as a normal message against Free/Pro quotas
- Missing key → deterministic stub stream (no crash)
- No Gemini / Anthropic / multi-model picker; Cursor is not a runtime

```bash
npm run test -w @chatai/api   # mock-HTTP gateway + web search + quota + Store entitlement tests
```

## Storage

- **Postgres (Supabase):** Store subscriptions/entitlements (`public.store_subscriptions`, one row per Supabase user id, with the Store user key hash). Set `DATABASE_URL`; apply migrations with `npm run migrate -w @chatai/api` (the Fly release command does this on deploy). Without `DATABASE_URL` (local dev) they stay in memory.
- **In memory:** conversations, messages, usage counters, rate limits. Run a single instance.
- A Collections outage keeps the persisted tier; Pro ends at `currentPeriodEnd` (+ grace) when Collections no longer reports the add-on.

## Deploy

`Dockerfile` + `fly.toml` at the repo root; guide: [docs/deploy-fly.md](../../docs/deploy-fly.md). With `NODE_ENV=production` the API refuses to boot unless `SUPABASE_URL`, `DATABASE_URL`, `XAI_API_KEY`, `MS_STORE_TENANT_ID`, `MS_STORE_CLIENT_ID`, `MS_STORE_CLIENT_SECRET` and `MS_STORE_PRO_STORE_ID` are set and `ALLOW_DEV_STUB_AUTH` is not.
