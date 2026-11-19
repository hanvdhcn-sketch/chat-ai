import type { FastifyInstance } from 'fastify';
import { requireAuth } from '../middleware/auth.js';

export async function authRoutes(app: FastifyInstance): Promise<void> {
  /** Verify current JWT / stub token and return profile + plan tier. */
  app.get('/v1/me', { preHandler: requireAuth }, async (request) => {
    return { user: request.user };
  });
}
