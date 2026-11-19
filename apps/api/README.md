# ChatAI API (Fastify)

BFF for the Windows client: auth verify, conversations/messages, SSE chat stream, usage/quota, **Microsoft Store billing**, AI gateway (Grok + Gemini).

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

- Free → `gemini-flash` only
- Pro → `grok` (default) or `gemini-pro` / `gemini-flash` / `grok-fast`
- With keys: streams from xAI (`/chat/completions`) or Gemini (`streamGenerateContent?alt=sse`)
- Missing key for the resolved model → deterministic stub stream (no crash)
- Cross-vendor fallback once when primary HTTP fails (same cost band)
- No Anthropic; Cursor is not a runtime

```bash
npm run test -w @chatai/api   # mock-HTTP gateway + quota + Store entitlement tests
```

## Storage

In-memory maps (usage + conversations + Store subscriptions). Redis/Postgres still optional for local.
