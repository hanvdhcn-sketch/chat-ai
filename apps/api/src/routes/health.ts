import type { FastifyInstance } from 'fastify';
import {
  config,
  isAiConfigured,
  isDatabaseConfigured,
  isMsStoreConfigured,
  isSupabaseConfigured,
} from '../config.js';
import { pingDatabase } from '../services/db.js';

export async function healthRoutes(app: FastifyInstance): Promise<void> {
  /** Liveness: no external calls — used by the host's health check. */
  app.get('/health', async () => ({
    ok: true,
    service: 'chatai-api',
    env: config.nodeEnv,
    stubs: {
      supabaseConfigured: isSupabaseConfigured(),
      databaseConfigured: isDatabaseConfigured(),
      aiConfigured: isAiConfigured(),
      msStoreConfigured: isMsStoreConfigured(),
      devStubAuth: config.allowDevStubAuth,
      /** @deprecated Stripe is not the end-user billing path. */
      stripeConfigured: false,
    },
  }));

  /** Readiness: verifies the Postgres connection (503 when unreachable). */
  app.get('/health/ready', async (_request, reply) => {
    if (!isDatabaseConfigured()) {
      return { ok: true, database: 'not_configured' };
    }
    const dbOk = await pingDatabase();
    if (!dbOk) {
      return reply.code(503).send({ ok: false, database: 'unreachable' });
    }
    return { ok: true, database: 'ok' };
  });
}
