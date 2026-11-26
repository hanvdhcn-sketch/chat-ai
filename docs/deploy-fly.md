# Deploy the Orbita API to Fly.io

The API is a single Fastify container (`Dockerfile`, `fly.toml` at the repo root). State that Pro depends on lives in Supabase Postgres; conversations and usage counters are still in memory, so run **exactly one machine**.

## 0. Supabase (once)

1. Create a project at <https://supabase.com>. Authentication → Providers: keep **Email** enabled (password sign-in and email code).
2. Project Settings → API: copy the **Project URL**, the **anon** key and (only if the project signs tokens with HS256) the **JWT Secret**.
3. Connect → **Session pooler** connection string: this is `DATABASE_URL` (replace `[YOUR-PASSWORD]`).

The migration `apps/api/migrations/001_store_subscriptions.sql` is applied automatically by Fly on every deploy (`release_command`).

## 1. Install flyctl and log in

```powershell
winget install Fly-io.flyctl   # or: iwr https://fly.io/install.ps1 -useb | iex
fly auth login
```

## 2. Create the app (from the repo root)

`app` in `fly.toml` must be globally unique, so pick your own name:

```powershell
fly launch --no-deploy --copy-config --name <your-app-name> --region sin
```

## 3. Set secrets

Values the API requires in production (it refuses to boot without them): `SUPABASE_URL`, `DATABASE_URL`, `XAI_API_KEY`, `MS_STORE_TENANT_ID`, `MS_STORE_CLIENT_ID`, `MS_STORE_CLIENT_SECRET`, `MS_STORE_PRO_STORE_ID`. Never set `ALLOW_DEV_STUB_AUTH`.

```powershell
fly secrets set `
  SUPABASE_URL="https://<ref>.supabase.co" `
  SUPABASE_JWT_SECRET="<legacy jwt secret, only if HS256>" `
  DATABASE_URL="postgresql://postgres.<ref>:<password>@aws-0-<region>.pooler.supabase.com:5432/postgres" `
  XAI_API_KEY="<xai key>" `
  MS_STORE_TENANT_ID="<azure tenant id>" `
  MS_STORE_CLIENT_ID="<azure app client id>" `
  MS_STORE_CLIENT_SECRET="<azure app secret>" `
  MS_STORE_PRO_STORE_ID="<9XXXXXXXXXXX store id of pro_monthly>" `
  MS_STORE_PRO_PRODUCT_ID="pro_monthly" `
  PUBLIC_API_URL="https://<your-app-name>.fly.dev"
```

Every other variable (models, quotas, web search) is optional; see `.env.example`.

## 4. Deploy and pin to one machine

```powershell
fly deploy
fly scale count 1
```

`fly deploy` builds the image, runs the migration on a temporary machine, then starts the app and waits for `/health`.

## 5. Verify

```powershell
curl https://<your-app-name>.fly.dev/health          # {"ok":true,...,"env":"production","devStubAuth":false}
curl https://<your-app-name>.fly.dev/health/ready    # {"ok":true,"database":"ok"}
curl -i https://<your-app-name>.fly.dev/v1/me        # 401 without a token
fly logs
```

The API base URL for the Windows build is `https://<your-app-name>.fly.dev`.

## 6. Build the Store MSIX against it

```powershell
cd apps\windows_client
.\scripts\build_store_msix.ps1 `
  -ApiBaseUrl "https://<your-app-name>.fly.dev" `
  -SupabaseUrl "https://<ref>.supabase.co" `
  -SupabaseAnonKey "<anon key>"
```

## Updating / rollback

```powershell
fly deploy           # new release (migrations run first)
fly releases         # history
fly deploy --image <previous image ref>   # roll back the code (migrations are additive)
```

## Render instead of Fly

New → Web Service → this repo, **Runtime: Docker**, Dockerfile path `Dockerfile`, health check path `/health`, same environment variables as above plus `NODE_ENV=production` and `PORT=3001`. Render has no release command: run the migration once from your machine with `DATABASE_URL=<pooler uri> npm run migrate -w @chatai/api`.
