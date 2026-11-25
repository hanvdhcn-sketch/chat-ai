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
| GET | `/health` | no | Config readiness flags (`msStoreConfigured`) |
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

Dev token: `Bearer stub:user_demo:free` or `stub:user_demo:pro`.

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

In-memory maps (usage + conversations + Store subscriptions). Redis/Postgres still optional for local.
