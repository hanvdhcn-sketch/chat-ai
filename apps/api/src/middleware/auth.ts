import type { FastifyReply, FastifyRequest } from 'fastify';
import { config } from '../config.js';
import type { AuthUser } from '../types/index.js';
import { resolvePlanTier } from '../services/subscriptions.js';
import {
  verifySupabaseJwt,
  type SupabaseVerifyOptions,
} from '../services/supabase-auth.js';

export type AuthDeps = {
  allowDevStubAuth: boolean;
  supabase: SupabaseVerifyOptions;
};

function defaultDeps(): AuthDeps {
  return {
    allowDevStubAuth: config.allowDevStubAuth,
    supabase: {
      url: config.supabase.url,
      jwtSecret: config.supabase.jwtSecret,
    },
  };
}

/**
 * Resolve a Bearer token to a user.
 * - Supabase access tokens (HS256 secret or ES256/RS256 JWKS) are verified.
 * - `stub:<userId>:<tier>` tokens are accepted only when ALLOW_DEV_STUB_AUTH=true
 *   and NODE_ENV is not production.
 * planTier is NOT taken from real tokens: it comes from the persisted Store
 * entitlement (stub tokens may pin a tier for local UI work only).
 */
export async function authenticateBearer(
  token: string,
  deps: AuthDeps = defaultDeps(),
): Promise<AuthUser | null> {
  if (token.startsWith('stub:')) {
    return deps.allowDevStubAuth ? devStubUser(token) : null;
  }
  return verifySupabaseJwt(token, deps.supabase);
}

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
  const user = await authenticateBearer(token);
  if (!user) {
    await reply.code(401).send({ error: 'invalid_token' });
    return;
  }

  if ((await resolvePlanTier(user.id)) === 'pro') {
    user.planTier = 'pro';
  }

  request.user = user;
}

function devStubUser(token: string): AuthUser {
  const parts = token.split(':');
  const id = parts[1] || 'user_demo';
  return {
    id,
    email: `${id}@example.com`,
    name: 'Demo User',
    locale: 'en',
    planTier: parts[2] === 'pro' ? 'pro' : 'free',
  };
}
