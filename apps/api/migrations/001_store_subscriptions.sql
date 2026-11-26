-- Orbita: persist Microsoft Store entitlements so Pro survives API restarts.
-- Apply with `npm run migrate -w @chatai/api` (needs DATABASE_URL) or paste into
-- the Supabase SQL editor. Idempotent.
--
-- One row per Orbita user (Supabase auth.users id). The raw User Store ID key is
-- never stored; only a SHA-256 prefix to correlate a Store account to a user.

create table if not exists public.store_subscriptions (
  user_id uuid primary key references auth.users (id) on delete cascade,
  store_product_id text not null,
  status text not null
    check (status in ('active', 'trialing', 'expired', 'revoked', 'unknown')),
  user_store_id_hash text,
  store_collection_item_id text,
  current_period_end timestamptz,
  trial_end timestamptz,
  grace_until timestamptz,
  last_verified_at timestamptz not null default now(),
  source text not null
    check (source in ('collections_api', 'stub', 'client_attested')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists store_subscriptions_user_store_id_hash_idx
  on public.store_subscriptions (user_store_id_hash)
  where user_store_id_hash is not null;

-- The API connects with the database owner role, which bypasses RLS. Enabling RLS
-- with no policies blocks the public anon / authenticated PostgREST roles, so a
-- signed-in user can never read or write entitlements through the Supabase API.
alter table public.store_subscriptions enable row level security;
revoke all on public.store_subscriptions from anon, authenticated;
