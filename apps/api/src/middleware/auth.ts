import type { FastifyReply, FastifyRequest } from 'fastify';
import { config, isSupabaseConfigured } from '../config.js';
import type { AuthUser } from '../types/index.js';
import { getUserPlanTierOverride } from '../services/store.js';

/**
 * Auth verify stub.
 * Production: verify Supabase JWT (HS256/JWKS) with SUPABASE_JWT_SECRET.
 * Local/dev: accepts Bearer stub tokens shaped like `stub:<userId>:<tier>`.
 * Store entitlement verify may override planTier in-memory until Postgres.
 */
export async function requireAuth(
  request: FastifyRequest,
  reply: FastifyReply,
): Promise<void> {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    await reply.code(401).send({ error: 'missing_bearer_token' });
    return;
  }

  const token = header.slice('Bearer '.length).trim();
  const user = await verifyTokenStub(token);
  if (!user) {
    await reply.code(401).send({ error: 'invalid_token' });
    return;
  }

  const override = getUserPlanTierOverride(user.id);
  if (override) {
    user.planTier = override;
  }

  request.user = user;
}

async function verifyTokenStub(token: string): Promise<AuthUser | null> {
  // Dev stub: Bearer stub:user_demo:free | stub:user_pro:pro
  if (token.startsWith('stub:')) {
    const parts = token.split(':');
    const id = parts[1] || 'user_demo';
    const tier = parts[2] === 'pro' ? 'pro' : 'free';
    return {
      id,
      email: `${id}@example.com`,
      name: 'Demo User',
      locale: 'en',
      planTier: tier,
    };
  }

  if (!isSupabaseConfigured()) {
    // Without Supabase secrets, only stub tokens work.
    return null;
  }

  // Placeholder for real JWT verification (jose / supabase-js).
  // Do not decode untrusted JWTs without signature check in production.
  void config.supabase.jwtSecret;
  return null;
}
