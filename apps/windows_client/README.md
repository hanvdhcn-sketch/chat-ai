# ChatAI — Flutter Windows client

Brand placeholder: **ChatAI**. Target: Microsoft Store via MSIX.  
**Billing:** Microsoft Store subscription / IAP (not Stripe).

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
  (`RequestPurchaseAsync`, `GetAppLicenseAsync`, User Store ID for Collections).
- **`in_app_purchase` is not the primary path** on Windows Store.
- Until the C++/WinRT bridge is linked in the runner, missing-plugin → **explicit stub**;
  Upgrade CTA still calls `POST /v1/billing/store/verify` with `stubGrantPro` (API allows only outside production).
- Restore purchases re-reads license (or stub) and re-verifies with the API.
- Manage / cancel: Microsoft Store account UI; app re-verifies on restore / next launch.

## Free badge / i18n

- Free: shows **Powered by ChatAI** badge; Pro hides it.
- Locale stubs: English + Vietnamese (`lib/l10n`).

## MSIX / Store

```bash
flutter pub run msix:create
```

Fill `msix_config` in `pubspec.yaml` with Partner Center identity before certification.
Create the **Pro subscription add-on** in Partner Center (SKU must match `MS_STORE_PRO_PRODUCT_ID`).
See root README for Store + Azure AD Collections notes.
