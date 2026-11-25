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
  --dart-define=STUB_AUTH_TOKEN=stub:user_demo:free \
  --dart-define=MS_STORE_PRO_PRODUCT_ID=pro_monthly
```

## Auth (Supabase hooks)

- Secure storage holds JWT / stub token.
- `AuthService` calls `GET /v1/me`.
- Wire magic link + Google via Supabase Auth + deep link `chatai://auth/callback`.
- Public only: `SUPABASE_URL`, `SUPABASE_ANON_KEY` via `--dart-define`.

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

## Free badge / i18n

- Free: shows **Powered by Orbita** badge; Pro hides it.
- Locale stubs: English + Vietnamese (`lib/l10n`).

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

3. For production API host: `-ApiBaseUrl https://your-api.example.com` (or pass `--dart-define=API_BASE_URL=…`).
Upload the `.msix` in Partner Center Packages; Store signs it. Do **not** expect local sideload of a `--store` package without Partner Center association.
See root README for Azure AD Collections notes.
