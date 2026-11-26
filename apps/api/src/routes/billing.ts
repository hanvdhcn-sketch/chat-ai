import type { FastifyInstance } from 'fastify';
import { requireAuth } from '../middleware/auth.js';
import { config, isMsStoreConfigured } from '../config.js';
import {
  issueCollectionsKeyToken,
  listStoreProductsPublic,
  verifyMsStoreEntitlement,
} from '../services/ms-store-entitlement.js';
import {
  getSubscription,
  resolvePlanTier,
} from '../services/subscriptions.js';

/**
 * Billing: Microsoft Store IAP / Store-managed subscription.
 * Stripe checkout/portal/webhook stubs are deprecated (410 Gone).
 */
export async function billingRoutes(app: FastifyInstance): Promise<void> {
  /** Public catalog of Store product ids the client should purchase. */
  app.get('/v1/billing/store/products', async () => listStoreProductsPublic());

  /**
   * Verify Store entitlement and sync plan_tier.
   * Body: { storeProductId?, userStoreId?, clientLicenseActive?, stubGrantPro? }
   */
  app.post(
    '/v1/billing/store/verify',
    { preHandler: requireAuth },
    async (request) => {
      const user = request.user!;
      const body = (request.body ?? {}) as {
        storeProductId?: string;
        userStoreId?: string;
        clientLicenseActive?: boolean;
        stubGrantPro?: boolean;
      };

      const result = await verifyMsStoreEntitlement(user.id, body);
      // Reflect override on the request user for this process (in-memory).
      if (result.planTier) {
        user.planTier = result.planTier;
      }

      return {
        planTier: result.planTier,
        subscription: result.subscription,
        verified: result.verified,
        stub: result.stub,
        reason: result.reason,
        msStoreConfigured: isMsStoreConfigured(),
        priceUsd: 9.99,
        trialDays: 7,
      };
    },
  );

  /**
   * Token for StoreContext.GetCustomerCollectionsIdAsync (User Store ID key).
   * 503 when Azure AD credentials are not configured (dev / stub path).
   */
  app.post(
    '/v1/billing/store/collections-token',
    { preHandler: requireAuth },
    async (request, reply) => {
      const token = await issueCollectionsKeyToken();
      if (!token) {
        return reply.code(503).send({
          error: 'ms_store_not_configured',
          message: 'Microsoft Store Collections is not configured.',
        });
      }
      return { serviceAccessToken: token, publisherUserId: request.user!.id };
    },
  );

  /** Current Store subscription snapshot for the authenticated user. */
  app.get(
    '/v1/billing/store/subscription',
    { preHandler: requireAuth },
    async (request) => {
      const user = request.user!;
      const entitled = await resolvePlanTier(user.id);
      return {
        planTier: entitled === 'pro' ? 'pro' : user.planTier,
        subscription: (await getSubscription(user.id)) ?? null,
        productId: config.msStore.proProductId,
        provider: 'microsoft_store',
      };
    },
  );

  // ---------------------------------------------------------------------------
  // Deprecated Stripe stubs — removed from the shipping path (MS Store only).
  // ---------------------------------------------------------------------------

  const stripeGone = {
    error: 'stripe_deprecated',
    message:
      'End-user Pro billing uses Microsoft Store IAP/subscription. Use POST /v1/billing/store/verify.',
    provider: 'microsoft_store',
  };

  app.post(
    '/v1/billing/checkout',
    { preHandler: requireAuth },
    async (_request, reply) => reply.code(410).send(stripeGone),
  );

  app.post(
    '/v1/billing/portal',
    { preHandler: requireAuth },
    async (_request, reply) => reply.code(410).send(stripeGone),
  );

  app.post('/v1/billing/webhook', async (_request, reply) =>
    reply.code(410).send(stripeGone),
  );
}
