# ChatAI — Flutter Windows client

Brand placeholder: **ChatAI**. Target: Microsoft Store via MSIX.

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
  --dart-define=STUB_AUTH_TOKEN=stub:user_demo:free
```

## Auth (Supabase hooks)

- Secure storage holds JWT / stub token.
- `AuthService` calls `GET /v1/me`.
- Wire magic link + Google via Supabase Auth + deep link `chatai://auth/callback` (M1).
- Public only: `SUPABASE_URL`, `SUPABASE_ANON_KEY` via `--dart-define`.

## Streaming

`ApiClient.streamMessage` POSTs to `/v1/conversations/:id/messages/stream` and parses SSE `data:` frames.

## Free badge / i18n

- Free: shows **Powered by ChatAI** badge; Pro hides it.
- Locale stubs: English + Vietnamese (`lib/l10n`).

## MSIX / Store

```bash
flutter pub run msix:create
```

Fill `msix_config` in `pubspec.yaml` with Partner Center identity before certification.
See root README for Store notes.
