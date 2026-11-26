import { config } from './config.js';

export type ProductionCheckInput = {
  nodeEnv: string;
  supabaseUrl: string;
  databaseUrl: string;
  xaiApiKey: string;
  msStoreTenantId: string;
  msStoreClientId: string;
  msStoreClientSecret: string;
  msStoreProStoreId: string;
  devStubAuthRequested: boolean;
};

export function currentCheckInput(): ProductionCheckInput {
  return {
    nodeEnv: config.nodeEnv,
    supabaseUrl: config.supabase.url,
    databaseUrl: config.databaseUrl,
    xaiApiKey: config.ai.xaiApiKey,
    msStoreTenantId: config.msStore.tenantId,
    msStoreClientId: config.msStore.clientId,
    msStoreClientSecret: config.msStore.clientSecret,
    msStoreProStoreId: config.msStore.proStoreId,
    devStubAuthRequested: process.env.ALLOW_DEV_STUB_AUTH === 'true',
  };
}

/**
 * Problems that must stop a production boot: without these the API would run
 * with stub auth, in-memory entitlements, or fail-closed billing.
 */
export function productionConfigProblems(
  input: ProductionCheckInput = currentCheckInput(),
): string[] {
  if (input.nodeEnv !== 'production') return [];
  const problems: string[] = [];
  const need = (value: string, name: string) => {
    if (!value.trim()) problems.push(`${name} is required in production`);
  };
  need(input.supabaseUrl, 'SUPABASE_URL');
  need(input.databaseUrl, 'DATABASE_URL');
  need(input.xaiApiKey, 'XAI_API_KEY');
  need(input.msStoreTenantId, 'MS_STORE_TENANT_ID');
  need(input.msStoreClientId, 'MS_STORE_CLIENT_ID');
  need(input.msStoreClientSecret, 'MS_STORE_CLIENT_SECRET');
  need(input.msStoreProStoreId, 'MS_STORE_PRO_STORE_ID');
  if (input.devStubAuthRequested) {
    problems.push('ALLOW_DEV_STUB_AUTH must not be set in production');
  }
  return problems;
}
