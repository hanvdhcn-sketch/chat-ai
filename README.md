# Orbita

Windows desktop chat AI app (Microsoft Store) + Fastify API.  
**AI runtime:** xAI Grok only. Cursor is for building, not end-user inference.

**Billing:** Microsoft Store IAP / Store-managed subscription (Free → Pro). **Not Stripe.**

Product display name: **Orbita**. Package identity (`ChatAI.Placeholder` / `@chatai/api`) stays stable for Store continuity.

## Monorepo layout

```
apps/
  api/                 Fastify BFF — auth, chat, usage, MS Store billing, AI gateway
  windows_client/      Flutter Windows client — chat UI, Store purchase/restore, SSE stream
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

# Stub Store verify → Pro (non-production; no Azure AD required)
curl -s -X POST http://localhost:3001/v1/billing/store/verify \
  -H 'Authorization: Bearer stub:user_demo:free' \
  -H 'Content-Type: application/json' \
  -d '{"stubGrantPro":true,"storeProductId":"pro_monthly"}'
```

## Quick start (Flutter Windows)

Requires Flutter SDK + Windows toolchain (see `apps/windows_client/README.md`).

```bash
cd apps/windows_client
flutter create --platforms=windows .   # once — materializes full Windows runner
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://localhost:3001
```

**Upgrade to Pro / Go Pro** opens the **in-app** Microsoft Store purchase UI via WinRT `StoreContext` (method channel `chatai/store_billing`), then `POST /v1/billing/store/verify`. Do not tell users to leave the app and search the Store for “Orbita Pro”. Unpackaged builds cannot complete Store payment (need MSIX + Partner Center add-on). Dev-only stub grant requires `ALLOW_STORE_STUB_GRANT=true`.

## Environment variables

| Variable | Where | Purpose |
|----------|--------|---------|
| `SUPABASE_URL` | API + client | Auth project URL |
| `SUPABASE_ANON_KEY` | Client (public) | Supabase anon key |
| `SUPABASE_SERVICE_ROLE_KEY` | API only | Server admin ops |
| `SUPABASE_JWT_SECRET` | API only | Verify JWTs |
| `DATABASE_URL` | API | Postgres |
| `REDIS_URL` | API | Rate limit / usage cache |
| `XAI_API_KEY` | API only | Grok inference + native web_search (Responses API) |
| `XAI_GROK_MODEL` | API | Pro flagship vendor id (default: current strongest stable, e.g. `grok-4.7`). Bump + redeploy when a new flagship ships — no code change. |
| `XAI_GROK_FAST_MODEL` | API | Free cheaper vendor id (default `grok-4.3`) |
| `XAI_GROK_VISION_MODEL` | API | Multimodal / image chats (default tracks Pro flagship) |
| `XAI_WEB_SEARCH_MODE` | API | `xai` (default) / `local` / `off` |
| `WEB_SEARCH_TIMEOUT_MS` | API | Search-enabled request timeout (default 90000) |
| `BRAVE_SEARCH_API_KEY` | API only | Optional; used when `XAI_WEB_SEARCH_MODE=local` |
| `MS_STORE_TENANT_ID` | API only | Azure AD tenant for Collections API |
| `MS_STORE_CLIENT_ID` | API only | Azure AD app client id |
| `MS_STORE_CLIENT_SECRET` | API only | Azure AD app secret |
| `MS_STORE_PRO_PRODUCT_ID` | API + client dart-define | Partner Center subscription SKU (default `pro_monthly`) |
| `API_BASE_URL` | Client dart-define | BFF base URL |

Full template: [`.env.example`](.env.example). **Do not commit `.env` or real keys.**

## Product defaults (from plan)

| Knob | Free | Pro |
|------|------|-----|
| Price | $0 | $9.99/mo · 7-day trial (if Partner Center allows) |
| Billing | — | Microsoft Store subscription add-on |
| Messages/day | 60 | 400 |
| Images/message | 3 (≤5 MB each) | 8 (≤8 MB each) |
| Images/day | 8 | 20 |
| Models | Grok Fast (`grok-fast` → `XAI_GROK_FAST_MODEL`, default `grok-4.3`) | Grok (`grok` → `XAI_GROK_MODEL`, current strongest stable; default `grok-4.7`) |
| Branding | “Powered by Orbita” badge | Hidden |
| UI languages | VI + EN | VI + EN |

## MSIX / Microsoft Store (short)

1. Partner Center: create app; open **Product identity** and paste into `apps/windows_client/pubspec.yaml` `msix_config`:
   - Package/Identity **Name** → `identity_name`
   - Package/Identity **Publisher** (`CN=…`) → `publisher`
   - **Publisher display name** → `publisher_display_name`
   - Keep `display_name: Orbita`; keep `identity_name` stable after association.
2. Create **Subscription add-on** with Store ID / product id exactly **`pro_monthly`** at **$9.99/mo**, optional 7-day trial; set `MS_STORE_PRO_PRODUCT_ID` if you ever change the id.
3. Enroll Azure AD app + Partner Center **service access** for Collections/Purchase API; set `MS_STORE_*` secrets on the API only.
4. Build Store package (unsigned; Store signs on upload):

   ```powershell
   cd apps/windows_client
   powershell -ExecutionPolicy Bypass -File .\scripts\build_store_msix.ps1 -ApiBaseUrl https://YOUR-API
   # → dist/msix/Orbita.msix
   ```

5. Upload package in Partner Center; privacy policy URL, age rating, bilingual listing; submit app + add-on.
6. Sandbox Microsoft account + Store flight install to test **Go Pro** in-app purchase.
7. WinRT bridge: `apps/windows_client/windows/runner/store_billing_plugin.cpp` (channel `chatai/store_billing`).
8. Certification smoke: HTTPS API in release builds; Store purchase works in sandbox.

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev:api` | Fastify watch mode |
| `npm run build:api` | Compile API to `dist/` |
| `npm run typecheck:api` | TypeScript check |
| `npm run test:api` | Gateway + quota + Store entitlement unit tests |

## Milestone

**M1 (chat core):** real xAI Grok gateway when `XAI_API_KEY` is set; clear stub stream when missing; SSE persist; Free→Grok Fast / Pro→Grok; message hard quota + token soft-cap + in-memory rate limit; Flutter stop/loading/error UX.

**M3 (billing):** MS Store products + verify entitlement stubs; Stripe checkout/portal/webhook return **410 Gone**. Live Collections verify when `MS_STORE_*` credentials are set.

Still stubs: Supabase JWT verify, Postgres, Redis. WinRT StoreContext bridge is linked in the Windows runner.
