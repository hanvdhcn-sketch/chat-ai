import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  productionConfigProblems,
  type ProductionCheckInput,
} from './config-check.js';

const complete: ProductionCheckInput = {
  nodeEnv: 'production',
  supabaseUrl: 'https://p.supabase.co',
  databaseUrl: 'postgresql://x',
  xaiApiKey: 'k',
  msStoreTenantId: 't',
  msStoreClientId: 'c',
  msStoreClientSecret: 's',
  msStoreProStoreId: '9NBLGGH4TNMP',
  devStubAuthRequested: false,
};

describe('productionConfigProblems', () => {
  it('is empty for a complete production config and outside production', () => {
    assert.deepEqual(productionConfigProblems(complete), []);
    assert.deepEqual(
      productionConfigProblems({
        ...complete,
        nodeEnv: 'development',
        databaseUrl: '',
        devStubAuthRequested: true,
      }),
      [],
    );
  });

  it('lists every missing production value and the stub-auth flag', () => {
    const problems = productionConfigProblems({
      ...complete,
      supabaseUrl: '',
      databaseUrl: ' ',
      msStoreProStoreId: '',
      devStubAuthRequested: true,
    });
    assert.equal(problems.length, 4);
    assert.ok(problems.some((p) => p.includes('SUPABASE_URL')));
    assert.ok(problems.some((p) => p.includes('DATABASE_URL')));
    assert.ok(problems.some((p) => p.includes('MS_STORE_PRO_STORE_ID')));
    assert.ok(problems.some((p) => p.includes('ALLOW_DEV_STUB_AUTH')));
  });
});
