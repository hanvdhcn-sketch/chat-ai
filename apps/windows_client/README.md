# Orbita — Flutter Windows client

Display name: **Orbita**. Target: Microsoft Store via MSIX.  
**Runtime:** xAI Grok only. **Billing:** Microsoft Store subscription / IAP (not Stripe).

Package Dart name stays `chatai`; MSIX `identity_name` is `PrecisionToolsLab.OrbitaAI` (Partner Center).

## Prerequisites

- Flutter SDK ≥ 3.5 with **Windows** desktop enabled (`flutter config --enable-windows-desktop`)
- Visual Studio 2022 with Desktop development with C++ (Windows build)

## First-time Windows runner

This scaffold ships app Dart code + a CMake placeholder. On a Windows machine with Flutter:

```bash
cd apps/windows_client
flutter create --platforms=windows .
flutter pub get
flutter run -d windows \
  --dart-define=API_BASE_URL=http://localhost:3001 \
  --dart-define=SUPABASE_URL=https://REF.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=ANON_KEY \
  --dart-define=MS_STORE_PRO_PRODUCT_ID=pro_monthly
```

Offline/dev without Supabase: run the API with `ALLOW_DEV_STUB_AUTH=true` and the app with
`--dart-define=ALLOW_DEV_STUB_AUTH=true` (optionally `STUB_AUTH_TOKEN=stub:user_demo:pro`). Release builds ignore this flag.

## Auth (Supabase)

- `AuthService` signs in against Supabase Auth REST (email + password, create account, or email one-time code), keeps the
  access + refresh token in SharedPreferences (swap to secure storage once ATL is installed), refreshes shortly before expiry
  and on a 401, and signs out locally even when offline.
- `AuthGate` (`lib/main.dart`) shows `SignInScreen` until there is a session; the API receives the Supabase JWT as the Bearer token.
- The `stub:` token and the Stub Free/Pro menu exist only with `--dart-define=ALLOW_DEV_STUB_AUTH=true` in a non-release build.
- Public only: `SUPABASE_URL`, `SUPABASE_ANON_KEY` via `--dart-define`. Google OAuth is not implemented.

## Streaming

`ApiClient.streamMessage` POSTs to `/v1/conversations/:id/messages/stream` and parses SSE `data:` frames.

## Billing (Microsoft Store)

- `StoreBillingService` (`lib/services/store_billing.dart`) owns purchase + restore.
- **Native path:** method channel `chatai/store_billing` → WinRT `Windows.Services.Store.StoreContext`
  (runner `store_billing_plugin.cpp`: `RequestPurchaseAsync`, `GetAppLicenseAsync`, optional Collections id).
- **`in_app_purchase` is not the primary path** on Windows Store.
- Go Pro opens the **in-app** Store purchase UI (requires MSIX + Partner Center subscription `pro_monthly` for real payment).
- Dev-only API stub grant: `--dart-define=ALLOW_STORE_STUB_GRANT=true` (Release never stubs silently).
- Restore re-reads Store add-on licenses and re-verifies with `POST /v1/billing/store/verify`.
- Manage / cancel: Microsoft Store account UI; app re-verifies on restore / next launch.
- Unpackaged builds (no package identity) show a localized friendly message
  ("Upgrading to Pro is only available in the version installed from Microsoft Store.");
  technical detail goes to `developer.log` (`chatai.store_billing`) and `OutputDebugString` only.
- Server-side activation: when the API has Azure AD credentials, the client fetches
  `POST /v1/billing/store/collections-token`, the runner exchanges it via
  `GetCustomerCollectionsIdAsync` for the User Store ID key, and `POST /v1/billing/store/verify`
  checks Collections (set `MS_STORE_PRO_STORE_ID` to the add-on's 9XXXXXXXXXXX Store ID).

## Free badge / i18n

- Free: shows **Powered by Orbita** badge; Pro hides it.
- UI languages (Settings picker, persisted): en, vi, zh, ja, ko, es, fr, de, pt-BR, hi (`lib/l10n`).

## MSIX / Store

Identity in `pubspec.yaml` `msix_config` (Partner Center Product identity):
- **Name** `PrecisionToolsLab.OrbitaAI` · **Publisher** `CN=97082A87-14EA-4209-8039-A9443BD7AD27`
- **Publisher display name** `Precision Tools Lab` · **Display name** `Orbita AI`
- Expected PFN (derived): `PrecisionToolsLab.OrbitaAI_2h9tr0fqkywqe`
- Device family: Windows 10/11 Desktop · request **runFullTrust** in submission notes

1. Create subscription add-on Store ID / product id **`pro_monthly`**.
2. Build Store package (output: `dist/msix/Orbita.msix`):

```powershell
cd apps/windows_client
powershell -ExecutionPolicy Bypass -File .\scripts\build_store_msix.ps1
# or:
dart run msix:create --store `
  --windows-build-args="--dart-define=MS_STORE_PRO_PRODUCT_ID=pro_monthly" `
  --output-path=..\..\dist\msix --output-name=Orbita
```

3. The script **requires** `-ApiBaseUrl`, `-SupabaseUrl` and `-SupabaseAnonKey` and exits with `BUILD REFUSED` for localhost / private hosts,
   plain http, placeholders or a service_role key; after building it checks that the Release `app.so` embeds both URLs.
   `-AllowLocalApi` is for non-Store smoke packs only:

```powershell
.\scripts\build_store_msix.ps1 -ApiBaseUrl https://your-api.example.com `
  -SupabaseUrl https://REF.supabase.co -SupabaseAnonKey ANON_KEY
```
Upload the `.msix` in Partner Center Packages; Store signs it. Do **not** expect local sideload of a `--store` package without Partner Center association.
See root README for Azure AD Collections notes.
