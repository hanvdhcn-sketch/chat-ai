import type { FastifyInstance } from 'fastify';
import {
  isAiConfigured,
  isStripeConfigured,
  isSupabaseConfigured,
} from '../config.js';

export async function healthRoutes(app: FastifyInstance): Promise<void> {
  app.get('/health', async () => ({
    ok: true,
    service: 'chatai-api',
    stubs: {
      supabaseConfigured: isSupabaseConfigured(),
      aiConfigured: isAiConfigured(),
      stripeConfigured: isStripeConfigured(),
    },
  }));
}
