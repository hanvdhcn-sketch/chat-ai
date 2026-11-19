import type { FastifyInstance } from 'fastify';
import { requireAuth } from '../middleware/auth.js';
import { getOrCreateUsage } from '../services/store.js';
import { config } from '../config.js';

export async function usageRoutes(app: FastifyInstance): Promise<void> {
  app.get('/v1/usage', { preHandler: requireAuth }, async (request) => {
    const user = request.user!;
    const usage = getOrCreateUsage(user.id, user.planTier);
    return {
      usage,
      rateLimitPerMin:
        user.planTier === 'pro'
          ? config.quotas.proRateLimitPerMin
          : config.quotas.freeRateLimitPerMin,
      branding: {
        showPoweredBy: user.planTier === 'free',
        label: 'Powered by ChatAI',
      },
    };
  });
}
