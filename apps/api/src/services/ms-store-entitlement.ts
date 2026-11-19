import { createHash } from 'node:crypto';
import { config, isMsStoreConfigured, type PlanTier } from '../config.js';
import type { StoreSubscription } from '../types/index.js';
import {
  getSubscription,
  setSubscription,
  setUserPlanTierOverride,
} from './store.js';

export type VerifyStoreBody = {
  storeProductId?: string;
  /** User Store ID key from Windows.Services.Store (Collections identity). */
  userStoreId?: string;
  /** Optional client-reported license flag — never trusted alone in production. */
  clientLicenseActive?: boolean;
  /**
   * Dev-only: force stub Pro without Azure AD.
   * Ignored when NODE_ENV=production or MS Store credentials are configured
   * (then real Collections path is required).
   */
  stubGrantPro?: boolean;
};

export type VerifyStoreResult = {
  planTier: PlanTier;
  subscription: StoreSubscription | null;
  verified: boolean;
  stub: boolean;
  reason?: string;
};

function hashStoreId(userStoreId: string): string {
  return createHash('sha256').update(userStoreId).digest('hex').slice(0, 32);
}

function nowIso(): string {
  return new Date().toISOString();
}

/**
 * Resolve whether the user currently owns the Pro Store subscription.
 *
 * Production path: Azure AD client-credentials → Microsoft Store Collections API
 * query for `storeProductId` using the client's User Store ID key.
 *
 * Stub path (no credentials / local): accept explicit `stubGrantPro` only outside
 * production, or mirror `clientLicenseActive` as a soft hint that still requires
 * a non-empty userStoreId so the flow is exercisable end-to-end.
 */
export async function verifyMsStoreEntitlement(
  userId: string,
  body: VerifyStoreBody,
  deps: {
    fetchFn?: typeof fetch;
    configured?: boolean;
    nodeEnv?: string;
  } = {},
): Promise<VerifyStoreResult> {
  const fetchFn = deps.fetchFn ?? fetch;
  const configured = deps.configured ?? isMsStoreConfigured();
  const nodeEnv = deps.nodeEnv ?? config.nodeEnv;
  const productId =
    body.storeProductId?.trim() || config.msStore.proProductId;

  if (productId !== config.msStore.proProductId) {
    return {
      planTier: 'free',
      subscription: getSubscription(userId) ?? null,
      verified: false,
      stub: !configured,
      reason: 'unknown_product',
    };
  }

  if (configured) {
    const userStoreId = body.userStoreId?.trim();
    if (!userStoreId) {
      const existing = getSubscription(userId);
      return {
        planTier:
          existing?.status === 'active' || existing?.status === 'trialing'
            ? 'pro'
            : 'free',
        subscription: existing ?? null,
        verified: false,
        stub: false,
        reason: 'missing_user_store_id',
      };
    }

    const active = await queryCollectionsEntitlement(userStoreId, productId, {
      fetchFn,
    });

    const sub: StoreSubscription = {
      userId,
      storeProductId: productId,
      status: active ? 'active' : 'expired',
      userStoreIdHash: hashStoreId(userStoreId),
      lastVerifiedAt: nowIso(),
      source: 'collections_api',
    };
    setSubscription(sub);
    setUserPlanTierOverride(userId, active ? 'pro' : 'free');
    return {
      planTier: active ? 'pro' : 'free',
      subscription: sub,
      verified: true,
      stub: false,
      reason: active ? 'entitlement_active' : 'entitlement_missing',
    };
  }

  // --- Stub / local path ---
  if (nodeEnv === 'production') {
    return {
      planTier: 'free',
      subscription: getSubscription(userId) ?? null,
      verified: false,
      stub: true,
      reason: 'ms_store_not_configured',
    };
  }

  const grant =
    body.stubGrantPro === true ||
    (body.clientLicenseActive === true && Boolean(body.userStoreId?.trim()));

  if (!grant) {
    const existing = getSubscription(userId);
    if (existing && (existing.status === 'active' || existing.status === 'trialing')) {
      setUserPlanTierOverride(userId, 'free');
      const revoked: StoreSubscription = {
        ...existing,
        status: 'revoked',
        lastVerifiedAt: nowIso(),
        source: 'stub',
      };
      setSubscription(revoked);
      return {
        planTier: 'free',
        subscription: revoked,
        verified: true,
        stub: true,
        reason: 'stub_revoked',
      };
    }
    return {
      planTier: 'free',
      subscription: existing ?? null,
      verified: true,
      stub: true,
      reason: 'stub_no_entitlement',
    };
  }

  const sub: StoreSubscription = {
    userId,
    storeProductId: productId,
    status: 'active',
    userStoreIdHash: body.userStoreId
      ? hashStoreId(body.userStoreId)
      : undefined,
    lastVerifiedAt: nowIso(),
    source: 'stub',
    trialEnd: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
  };
  setSubscription(sub);
  setUserPlanTierOverride(userId, 'pro');
  return {
    planTier: 'pro',
    subscription: sub,
    verified: true,
    stub: true,
    reason: 'stub_granted',
  };
}

/**
 * Call Microsoft Store Collections API.
 * Spec sketch (subject to Microsoft docs at implement time):
 *   POST {collectionsBaseUrl}/collections/query
 *   Authorization: Bearer <AAD token>
 *   Body includes User Store ID + product filter.
 *
 * This implementation obtains an AAD token then performs the query.
 * Until credentials + Partner Center wiring are live, prefer the stub path.
 */
async function queryCollectionsEntitlement(
  userStoreId: string,
  storeProductId: string,
  opts: { fetchFn: typeof fetch },
): Promise<boolean> {
  const token = await fetchAzureAdToken(opts.fetchFn);
  if (!token) return false;

  const url = `${config.msStore.collectionsBaseUrl.replace(/\/$/, '')}/collections/query`;
  const res = await opts.fetchFn(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      beneficiaries: [
        {
          identityType: 'b2b',
          identityValue: userStoreId,
          localTicketReference: 'chatai',
        },
      ],
      productSkuIds: [{ productId: storeProductId }],
    }),
  });

  if (!res.ok) {
    return false;
  }

  const data = (await res.json()) as {
    items?: Array<{ productId?: string; status?: string }>;
  };
  const items = data.items ?? [];
  return items.some(
    (item) =>
      item.productId === storeProductId &&
      (item.status === 'Active' ||
        item.status === 'active' ||
        item.status === 'Trial' ||
        item.status === 'trialing'),
  );
}

async function fetchAzureAdToken(fetchFn: typeof fetch): Promise<string | null> {
  const { tenantId, clientId, clientSecret, collectionsScope } = config.msStore;
  const tokenUrl = `https://login.microsoftonline.com/${tenantId}/oauth2/v2.0/token`;
  const body = new URLSearchParams({
    grant_type: 'client_credentials',
    client_id: clientId,
    client_secret: clientSecret,
    scope: collectionsScope,
  });

  const res = await fetchFn(tokenUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });
  if (!res.ok) return null;
  const data = (await res.json()) as { access_token?: string };
  return data.access_token ?? null;
}

export function listStoreProductsPublic() {
  return {
    products: [
      {
        storeProductId: config.msStore.proProductId,
        sku: 'pro',
        priceUsd: 9.99,
        billingPeriod: 'month',
        trialDays: 7,
        title: 'ChatAI Pro',
      },
    ],
    provider: 'microsoft_store' as const,
  };
}
