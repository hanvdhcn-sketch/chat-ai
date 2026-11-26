import assert from 'node:assert/strict';
import { beforeEach, describe, it } from 'node:test';
import type { StoreSubscription } from '../types/index.js';
import {
  MemorySubscriptionRepo,
  PgSubscriptionRepo,
  getSubscription,
  resolvePlanTier,
  saveSubscription,
  setSubscriptionRepo,
  subscriptionGrantsPro,
} from './subscriptions.js';

const USER = '0b6f5a54-3f2d-4d2b-9a3b-6a1c3f2f8e11';

function sub(overrides: Partial<StoreSubscription> = {}): StoreSubscription {
  return {
    userId: USER,
    storeProductId: 'pro_monthly',
    status: 'active',
    userStoreIdHash: 'abc123',
    lastVerifiedAt: '2026-01-01T00:00:00.000Z',
    source: 'collections_api',
    ...overrides,
  };
}

describe('subscriptionGrantsPro', () => {
  it('grants Pro only for active/trialing within the period', () => {
    const now = new Date('2026-06-01T00:00:00Z');
    assert.equal(subscriptionGrantsPro(undefined, now), false);
    assert.equal(subscriptionGrantsPro(sub(), now), true);
    assert.equal(subscriptionGrantsPro(sub({ status: 'trialing' }), now), true);
    assert.equal(subscriptionGrantsPro(sub({ status: 'expired' }), now), false);
    assert.equal(subscriptionGrantsPro(sub({ status: 'revoked' }), now), false);
    assert.equal(
      subscriptionGrantsPro(sub({ currentPeriodEnd: '2026-05-01T00:00:00Z' }), now),
      false,
    );
    assert.equal(
      subscriptionGrantsPro(
        sub({
          currentPeriodEnd: '2026-05-01T00:00:00Z',
          graceUntil: '2026-07-01T00:00:00Z',
        }),
        now,
      ),
      true,
    );
  });
});

describe('subscription persistence', () => {
  beforeEach(() => setSubscriptionRepo(new MemorySubscriptionRepo()));

  it('survives a simulated restart when backed by the same repo', async () => {
    const shared = new MemorySubscriptionRepo();
    setSubscriptionRepo(shared);
    await saveSubscription(sub());
    setSubscriptionRepo(shared); // new process, same database
    assert.equal(await resolvePlanTier(USER), 'pro');
    assert.equal((await getSubscription(USER))?.userStoreIdHash, 'abc123');
  });
});

describe('PgSubscriptionRepo', () => {
  it('upserts by user id and maps rows back', async () => {
    const calls: Array<{ text: string; values?: unknown[] }> = [];
    const row = {
      user_id: USER,
      store_product_id: 'pro_monthly',
      status: 'active',
      user_store_id_hash: 'abc123',
      store_collection_item_id: null,
      current_period_end: new Date('2026-07-01T00:00:00Z'),
      trial_end: null,
      grace_until: null,
      last_verified_at: new Date('2026-06-01T00:00:00Z'),
      source: 'collections_api',
    };
    const repo = new PgSubscriptionRepo({
      query: (async (text: string, values?: unknown[]) => {
        calls.push({ text, values });
        return { rows: text.includes('select') ? [row] : [], rowCount: 1 };
      }) as never,
    });

    await repo.save(sub({ currentPeriodEnd: '2026-07-01T00:00:00.000Z' }));
    assert.match(calls[0]!.text, /on conflict \(user_id\) do update/);
    assert.equal(calls[0]!.values?.[0], USER);
    assert.equal(calls[0]!.values?.[3], 'abc123');

    const loaded = await repo.get(USER);
    assert.equal(loaded?.status, 'active');
    assert.equal(loaded?.currentPeriodEnd, '2026-07-01T00:00:00.000Z');
    assert.equal(loaded?.userStoreIdHash, 'abc123');
  });

  it('ignores non-uuid (dev stub) ids on read and refuses to write them', async () => {
    const repo = new PgSubscriptionRepo({
      query: (async () => {
        throw new Error('should not query');
      }) as never,
    });
    assert.equal(await repo.get('user_demo'), undefined);
    await assert.rejects(repo.save(sub({ userId: 'user_demo' })));
  });
});
