# ChatAI

Windows desktop chat AI app (Microsoft Store) + Fastify API.  
**AI runtime:** xAI Grok + Google Gemini only. No Anthropic/Claude. Cursor is for building, not end-user inference.

Brand name is a **placeholder** until Store listing / domain is finalized.

## Monorepo layout

```
apps/
  api/                 Fastify BFF — auth, chat, usage, Stripe stubs, AI gateway
  windows_client/      Flutter Windows client — chat UI, Supabase auth hooks, SSE stream
docs/                  Extra notes (optional)
.env.example           All env var names (copy → apps/api/.env; never commit secrets)
```

## Quick start (API)

```bash
cp .env.example apps/api/.env
npm install
npm run dev:api
# → http://localhost:3001/health
```

Dev auth without Supabase: `Authorization: Bearer stub:user_demo:free` (or `:pro`).

```bash
# Create conversation
curl -s -X POST http://localhost:3001/v1/conversations \
  -H 'Authorization: Bearer stub:user_demo:free' \
  -H 'Content-Type: application/json' -d '{}'

# Stream a reply (SSE)
curl -N -X POST http://localhost:3001/v1/conversations/<id>/messages/stream \
  -H 'Authorization: Bearer stub:user_demo:free' \
  -H 'Content-Type: application/json' \
  -d '{"content":"Hello"}'
```

## Quick start (Flutter Windows)

Requires Flutter SDK + Windows toolchain (see `apps/windows_client/README.md`).

```bash
cd apps/windows_client
flutter create --platforms=windows .   # once — materializes full Windows runner
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3001
```

## Environment variables

| Variable | Where | Purpose |
|----------|--------|---------|
| `SUPABASE_URL` | API + client | Auth project URL |
| `SUPABASE_ANON_KEY` | Client (public) | Supabase anon key |
| `SUPABASE_SERVICE_ROLE_KEY` | API only | Server admin ops |
| `SUPABASE_JWT_SECRET` | API only | Verify JWTs |
| `DATABASE_URL` | API | Postgres |
| `REDIS_URL` | API | Rate limit / usage cache |
| `XAI_API_KEY` | API only | Grok inference (SSE via OpenAI-compatible chat completions) |
| `GOOGLE_GEMINI_API_KEY` | API only | Gemini inference (`streamGenerateContent` SSE) |
| `XAI_GROK_MODEL` / `XAI_GROK_FAST_MODEL` | API | Optional Grok model ids |
| `GEMINI_FLASH_MODEL` / `GEMINI_PRO_MODEL` | API | Optional Gemini model ids |
| `STRIPE_SECRET_KEY` | API only | Checkout / portal |
| `STRIPE_WEBHOOK_SECRET` | API only | Webhook verify |
| `STRIPE_PRICE_PRO_MONTHLY` | API | Pro $9.99/mo price id |
| `API_BASE_URL` | Client dart-define | BFF base URL |

Full template: [`.env.example`](.env.example). **Do not commit `.env` or real keys.**

## Product defaults (from plan)

| Knob | Free | Pro |
|------|------|-----|
| Price | $0 | $9.99/mo · 7-day trial |
| Messages/day | ~40 | ~400 |
| Models | Gemini Flash | Grok (default) + Gemini |
| Branding | “Powered by …” badge | Hidden |
| UI languages | VI + EN | VI + EN |

## MSIX / Microsoft Store (short)

1. Partner Center: create app identity (publisher, package family name).
2. Fill `msix_config` in `apps/windows_client/pubspec.yaml`.
3. Build signed MSIX (`msix` package or CI); capability **InternetClient** only if possible.
4. Privacy policy URL, age rating, bilingual Store listing.
5. Confirm digital-goods policy vs Stripe Checkout (browser) before submit.
6. Certification smoke: no localhost-only networking in release builds; auth/billing over HTTPS.

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev:api` | Fastify watch mode |
| `npm run build:api` | Compile API to `dist/` |
| `npm run typecheck:api` | TypeScript check |
| `npm run test:api` | Gateway + quota unit tests (mock HTTP) |

## Milestone

**M1 (chat core):** real xAI Grok + Gemini gateway when keys are set; clear stub stream when missing; SSE persist; Free→Gemini Flash / Pro→Grok(+Gemini); message hard quota + token soft-cap + in-memory rate limit; Flutter stop/loading/error UX.

Still stubs: Supabase JWT verify, Postgres, Redis, Stripe live Checkout.
