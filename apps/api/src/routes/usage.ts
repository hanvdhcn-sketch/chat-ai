import type { FastifyInstance } from 'fastify';
import { requireAuth } from '../middleware/auth.js';
import { getOrCreateUsage } from '../services/store.js';
import { config } from '../config.js';
import {
  effectiveImageLimits,
  monthlyImageSoftCapStatus,
  quotaResetsAtIso,
} from '../services/quota-context.js';

export async function usageRoutes(app: FastifyInstance): Promise<void> {
  app.get('/v1/usage', { preHandler: requireAuth }, async (request) => {
    const user = request.user!;
    const usage = getOrCreateUsage(user.id, user.planTier);
    const images = effectiveImageLimits(user.planTier, usage);
    const monthlyImageSoftCap = monthlyImageSoftCapStatus(
      usage,
      user.planTier,
    );
    return {
      usage,
      rateLimitPerMin:
        user.planTier === 'pro'
          ? config.quotas.proRateLimitPerMin
          : config.quotas.freeRateLimitPerMin,
      resetsAt: quotaResetsAtIso(usage.windowStart),
      imageLimits: {
        maxImagesPerMessage: images.maxImagesPerMessage,
        maxImageBytes: images.maxImageBytes,
        maxImagesPerDay: images.maxImagesPerDay,
      },
      // Only present when Pro monthly soft-cap is already hit (not marketed).
      ...(monthlyImageSoftCap
        ? { monthlyImageSoftCap }
        : {}),
      branding: {
        showPoweredBy: user.planTier === 'free',
        label: 'Powered by Orbita',
      },
    };
  });
}
