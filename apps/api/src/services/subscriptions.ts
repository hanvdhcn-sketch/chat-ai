import type { PlanTier } from '../config.js';
import { isDatabaseConfigured } from '../config.js';
import type {
  StoreSubscription,
  StoreSubscriptionStatus,
} from '../types/index.js';
import { getPool, type SqlClient } from './db.js';

/** Persistence for Microsoft Store entitlements (one row per Orbita user). */
export interface SubscriptionRepo {
  get(userId: string): Promise<StoreSubscription | undefined>;
  save(sub: StoreSubscription): Promise<void>;
}

export class MemorySubscriptionRepo implements SubscriptionRepo {
  private readonly rows = new Map<string, StoreSubscription>();

  async get(userId: string): Promise<StoreSubscription | undefined> {
    return this.rows.get(userId);
  }

  async save(sub: StoreSubscription): Promise<void> {
    this.rows.set(sub.userId, sub);
  }

  clear(): void {
    this.rows.clear();
  }
}

type SubscriptionRow = {
  user_id: string;
  store_product_id: string;
  status: StoreSubscriptionStatus;
  user_store_id_hash: string | null;
  store_collection_item_id: string | null;
  current_period_end: Date | string | null;
  trial_end: Date | string | null;
  grace_until: Date | string | null;
  last_verified_at: Date | string;
  source: StoreSubscription['source'];
};

function iso(value: Date | string | null): string | undefined {
  if (value === null) return undefined;
  return value instanceof Date ? value.toISOString() : value;
}

export function rowToSubscription(row: SubscriptionRow): StoreSubscription {
  return {
    userId: row.user_id,
    storeProductId: row.store_product_id,
    status: row.status,
    userStoreIdHash: row.user_store_id_hash ?? undefined,
    storeCollectionItemId: row.store_collection_item_id ?? undefined,
    currentPeriodEnd: iso(row.current_period_end),
    trialEnd: iso(row.trial_end),
    graceUntil: iso(row.grace_until),
    lastVerifiedAt: iso(row.last_verified_at) ?? new Date().toISOString(),
    source: row.source,
  };
}

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export class PgSubscriptionRepo implements SubscriptionRepo {
  constructor(private readonly db: SqlClient) {}

  async get(userId: string): Promise<StoreSubscription | undefined> {
    if (!UUID_RE.test(userId)) return undefined;
    const { rows } = await this.db.query<SubscriptionRow>(
      `select user_id, store_product_id, status, user_store_id_hash,
              store_collection_item_id, current_period_end, trial_end,
              grace_until, last_verified_at, source
         from public.store_subscriptions
        where user_id = $1`,
      [userId],
    );
    return rows[0] ? rowToSubscription(rows[0]) : undefined;
  }

  async save(sub: StoreSubscription): Promise<void> {
    if (!UUID_RE.test(sub.userId)) {
      throw new Error('Cannot persist a subscription for a non-Supabase user id');
    }
    await this.db.query(
      `insert into public.store_subscriptions
         (user_id, store_product_id, status, user_store_id_hash,
          store_collection_item_id, current_period_end, trial_end,
          grace_until, last_verified_at, source)
       values ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       on conflict (user_id) do update set
         store_product_id = excluded.store_product_id,
         status = excluded.status,
         user_store_id_hash = coalesce(excluded.user_store_id_hash,
                                       store_subscriptions.user_store_id_hash),
         store_collection_item_id = excluded.store_collection_item_id,
         current_period_end = excluded.current_period_end,
         trial_end = excluded.trial_end,
         grace_until = excluded.grace_until,
         last_verified_at = excluded.last_verified_at,
         source = excluded.source,
         updated_at = now()`,
      [
        sub.userId,
        sub.storeProductId,
        sub.status,
        sub.userStoreIdHash ?? null,
        sub.storeCollectionItemId ?? null,
        sub.currentPeriodEnd ?? null,
        sub.trialEnd ?? null,
        sub.graceUntil ?? null,
        sub.lastVerifiedAt,
        sub.source,
      ],
    );
  }
}

const CACHE_TTL_MS = 30_000;

let repo: SubscriptionRepo | null = null;
const cache = new Map<
  string,
  { at: number; value: StoreSubscription | undefined }
>();

function activeRepo(): SubscriptionRepo {
  if (!repo) {
    repo = isDatabaseConfigured()
      ? new PgSubscriptionRepo(getPool())
      : new MemorySubscriptionRepo();
  }
  return repo;
}

/** Test seam. Pass null to fall back to env-based selection. */
export function setSubscriptionRepo(next: SubscriptionRepo | null): void {
  repo = next;
  cache.clear();
}

export async function getSubscription(
  userId: string,
): Promise<StoreSubscription | undefined> {
  const hit = cache.get(userId);
  if (hit && Date.now() - hit.at < CACHE_TTL_MS) return hit.value;
  const value = await activeRepo().get(userId);
  cache.set(userId, { at: Date.now(), value });
  return value;
}

export async function saveSubscription(sub: StoreSubscription): Promise<void> {
  await activeRepo().save(sub);
  cache.set(sub.userId, { at: Date.now(), value: sub });
}

export function subscriptionGrantsPro(
  sub: StoreSubscription | undefined,
  now: Date = new Date(),
): boolean {
  if (!sub) return false;
  if (sub.status !== 'active' && sub.status !== 'trialing') return false;
  const end = sub.graceUntil ?? sub.currentPeriodEnd;
  if (end && new Date(end).getTime() < now.getTime()) return false;
  return true;
}

/** Plan tier derived from the persisted entitlement. */
export async function resolvePlanTier(userId: string): Promise<PlanTier> {
  return subscriptionGrantsPro(await getSubscription(userId)) ? 'pro' : 'free';
}

/** Test helper */
export function resetSubscriptions(): void {
  cache.clear();
  if (repo instanceof MemorySubscriptionRepo) repo.clear();
}
