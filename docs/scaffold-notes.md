# Scaffold notes (M0 / M1 / M3 billing)

- Backend choice: **Fastify** (Node 22) — lean BFF for SSE streaming and **Microsoft Store** entitlement verify.
- Client: **Flutter Windows** Dart sources + MSIX config; regenerate Windows runner with `flutter create --platforms=windows .` on a Windows/Flutter host.
- Billing: **MS Store IAP / subscription** (not Stripe). Stripe checkout/portal/webhook routes return 410 Gone.
- Brand: **Orbita** (display). Package ids stay `chatai` / `ChatAI.Placeholder` for Store continuity.
- Secrets: only names in `.env.example`; never commit real keys. Azure AD Store credentials stay server-side.
