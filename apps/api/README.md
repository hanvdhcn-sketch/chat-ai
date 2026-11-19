# ChatAI API (Fastify)

BFF for the Windows client: auth verify, conversations/messages, SSE chat stream, usage/quota, Stripe stubs, AI gateway (Grok + Gemini).

## Run

```bash
cp ../../.env.example .env
# from repo root:
npm install
npm run dev:api
```

## Routes (MVP stubs)

| Method | Path | Auth | Notes |
|--------|------|------|-------|
| GET | `/health` | no | Config readiness flags |
| GET | `/v1/me` | Bearer | Profile + `planTier` |
| GET/POST | `/v1/conversations` | Bearer | List / create |
| GET | `/v1/conversations/:id` | Bearer | Conversation + messages |
| GET/POST | `/v1/conversations/:id/messages` | Bearer | History / append user msg |
| POST | `/v1/conversations/:id/messages/stream` | Bearer | SSE AI stream |
| GET | `/v1/usage` | Bearer | Message + token soft-cap |
| POST | `/v1/billing/checkout` | Bearer | Stripe Checkout stub |
| POST | `/v1/billing/portal` | Bearer | Customer Portal stub |
| POST | `/v1/billing/webhook` | Stripe sig | Subscription sync stub |

Dev token: `Bearer stub:user_demo:free` or `stub:user_demo:pro`.

## AI gateway

- Free → `gemini-flash`
- Pro → `grok` (default) or Gemini variants
- Without `XAI_API_KEY` / `GOOGLE_GEMINI_API_KEY`, returns a deterministic stub stream
- No Anthropic; Cursor is not a runtime

## Storage

In-memory maps for M0. Replace with Postgres + Redis before M1 production staging.
