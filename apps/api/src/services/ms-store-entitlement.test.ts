import assert from 'node:assert/strict';
import { describe, it, beforeEach } from 'node:test';
import {
  listStoreProductsPublic,
  verifyMsStoreEntitlement,
} from './ms-store-entitlement.js';
import { resetStore, getUserPlanTierOverride } from './store.js';

describe('ms-store-entitlement', () => {
  beforeEach(() => {
    resetStore();
  });

  it('lists Pro monthly Store product', () => {
    const catalog = listStoreProductsPublic();
    assert.equal(catalog.provider, 'microsoft_store');
    assert.equal(catalog.products.length, 1);
    assert.equal(catalog.products[0]?.priceUsd, 9.99);
    assert.ok(catalog.products[0]?.storeProductId);
  });

  it('stub-grants Pro outside production when stubGrantPro=true', async () => {
    const result = await verifyMsStoreEntitlement(
      'user_a',
      { stubGrantPro: true, storeProductId: 'pro_monthly' },
      { configured: false, nodeEnv: 'development' },
    );
    assert.equal(result.planTier, 'pro');
    assert.equal(result.stub, true);
    assert.equal(result.verified, true);
    assert.equal(getUserPlanTierOverride('user_a'), 'pro');
  });

  it('rejects unknown store product id', async () => {
    const result = await verifyMsStoreEntitlement(
      'user_b',
      { stubGrantPro: true, storeProductId: 'not_a_real_sku' },
      { configured: false, nodeEnv: 'development' },
    );
    assert.equal(result.planTier, 'free');
    assert.equal(result.reason, 'unknown_product');
  });

  it('does not stub-grant in production without credentials', async () => {
    const result = await verifyMsStoreEntitlement(
      'user_c',
      { stubGrantPro: true },
      { configured: false, nodeEnv: 'production' },
    );
    assert.equal(result.planTier, 'free');
    assert.equal(result.reason, 'ms_store_not_configured');
  });

  it('queries Collections API when configured', async () => {
    const calls: string[] = [];
    const fetchFn = (async (input: RequestInfo | URL, init?: RequestInit) => {
      const url = String(input);
      calls.push(url);
      if (url.includes('login.microsoftonline.com')) {
        return new Response(JSON.stringify({ access_token: 'tok' }), {
          status: 200,
        });
      }
      if (url.includes('collections')) {
        assert.equal(init?.method, 'POST');
        return new Response(
          JSON.stringify({
            items: [{ productId: 'pro_monthly', status: 'Active' }],
          }),
          { status: 200 },
        );
      }
      return new Response('unexpected', { status: 500 });
    }) as typeof fetch;

    const result = await verifyMsStoreEntitlement(
      'user_d',
      {
        storeProductId: 'pro_monthly',
        userStoreId: 'store-id-key-xyz',
      },
      { configured: true, fetchFn, nodeEnv: 'production' },
    );

    assert.equal(result.planTier, 'pro');
    assert.equal(result.stub, false);
    assert.equal(result.verified, true);
    assert.ok(calls.some((u) => u.includes('login.microsoftonline.com')));
    assert.ok(calls.some((u) => u.includes('collections')));
  });

  it('requires userStoreId when Collections is configured', async () => {
    const result = await verifyMsStoreEntitlement(
      'user_e',
      { storeProductId: 'pro_monthly' },
      { configured: true, nodeEnv: 'production' },
    );
    assert.equal(result.verified, false);
    assert.equal(result.reason, 'missing_user_store_id');
  });
});
