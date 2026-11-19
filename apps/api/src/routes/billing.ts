import type { FastifyInstance } from 'fastify';
import { requireAuth } from '../middleware/auth.js';
import { config, isStripeConfigured } from '../config.js';

/**
 * Stripe stubs: Checkout Session + Customer Portal + webhook.
 * Webhook is the source of truth for plan_tier; never trust the client.
 */
export async function billingRoutes(app: FastifyInstance): Promise<void> {
  app.post(
    '/v1/billing/checkout',
    { preHandler: requireAuth },
    async (request, reply) => {
      const user = request.user!;
      if (!isStripeConfigured()) {
        return reply.code(503).send({
          error: 'stripe_not_configured',
          hint: 'Set STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET, STRIPE_PRICE_PRO_MONTHLY',
          stub: {
            checkoutUrl: null,
            trialDays: 7,
            priceUsd: 9.99,
            userId: user.id,
          },
        });
      }

      // Production: stripe.checkout.sessions.create({ mode: 'subscription',
      // trial_period_days: 7, metadata: { user_id }, line_items: [{ price }] })
      return {
        checkoutUrl: `${config.publicApiUrl}/stub/stripe-checkout?user=${user.id}`,
        trialDays: 7,
        priceUsd: 9.99,
      };
    },
  );

  app.post(
    '/v1/billing/portal',
    { preHandler: requireAuth },
    async (request, reply) => {
      const user = request.user!;
      if (!isStripeConfigured()) {
        return reply.code(503).send({
          error: 'stripe_not_configured',
          stub: { portalUrl: null, userId: user.id },
        });
      }
      return {
        portalUrl: `${config.publicApiUrl}/stub/stripe-portal?user=${user.id}`,
      };
    },
  );

  /**
   * Stripe webhook stub — verify signature with STRIPE_WEBHOOK_SECRET in prod.
   * Handle: checkout.session.completed, customer.subscription.updated/deleted,
   * invoice.payment_failed (grace 3 days).
   */
  app.post('/v1/billing/webhook', async (request, reply) => {
    const signature = request.headers['stripe-signature'];
    if (!isStripeConfigured()) {
      app.log.warn(
        { hasSignature: Boolean(signature) },
        'stripe webhook received but Stripe not configured',
      );
      return reply.code(503).send({ error: 'stripe_not_configured' });
    }

    // Production: constructEvent(rawBody, signature, webhookSecret) then idempotent sync.
    const event = request.body as { type?: string; id?: string } | null;
    app.log.info(
      { eventType: event?.type, eventId: event?.id },
      'stripe webhook stub accepted',
    );

    return { received: true, stub: true };
  });
}
