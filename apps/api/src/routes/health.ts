import type { FastifyInstance } from 'fastify';
import {
  isAiConfigured,
  isMsStoreConfigured,
  isSupabaseConfigured,
} from '../config.js';

export async function healthRoutes(app: FastifyInstance): Promise<void> {
  app.get('/health', async () => ({
    ok: true,
    service: 'chatai-api',
    stubs: {
      supabaseConfigured: isSupabaseConfigured(),
      aiConfigured: isAiConfigured(),
      msStoreConfigured: isMsStoreConfigured(),
      /** @deprecated Stripe is not the end-user billing path. */
      stripeConfigured: false,
    },
  }));
}
