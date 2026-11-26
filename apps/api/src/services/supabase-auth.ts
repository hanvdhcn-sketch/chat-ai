import {
  createRemoteJWKSet,
  decodeProtectedHeader,
  jwtVerify,
  type JWTPayload,
  type JWTVerifyGetKey,
} from 'jose';
import type { AuthUser } from '../types/index.js';

export type SupabaseVerifyOptions = {
  /** Project URL, e.g. https://abcd.supabase.co */
  url: string;
  /** Legacy HS256 JWT secret (Project Settings → API → JWT Secret). */
  jwtSecret?: string;
  /** Test seam / custom key resolver for asymmetric (ES256/RS256) tokens. */
  jwks?: JWTVerifyGetKey;
};

const remoteJwksByUrl = new Map<string, JWTVerifyGetKey>();

function jwksFor(url: string): JWTVerifyGetKey {
  const base = url.replace(/\/$/, '');
  let jwks = remoteJwksByUrl.get(base);
  if (!jwks) {
    jwks = createRemoteJWKSet(new URL(`${base}/auth/v1/.well-known/jwks.json`));
    remoteJwksByUrl.set(base, jwks);
  }
  return jwks;
}

function stringClaim(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() ? value.trim() : undefined;
}

function toAuthUser(payload: JWTPayload): AuthUser | null {
  const id = stringClaim(payload.sub);
  if (!id) return null;
  const meta = (payload.user_metadata ?? {}) as Record<string, unknown>;
  const locale = stringClaim(meta.locale);
  return {
    id,
    email: stringClaim(payload.email) ?? '',
    name: stringClaim(meta.full_name) ?? stringClaim(meta.name),
    locale: locale === 'vi' ? 'vi' : 'en',
    planTier: 'free',
  };
}

/**
 * Verify a Supabase Auth access token (signature, expiry, issuer, audience).
 * HS256 tokens use the legacy JWT secret; ES256/RS256 tokens use the project's
 * published JWKS. Returns null for anything that does not verify.
 */
export async function verifySupabaseJwt(
  token: string,
  opts: SupabaseVerifyOptions,
): Promise<AuthUser | null> {
  if (!opts.url) return null;
  try {
    const { alg } = decodeProtectedHeader(token);
    const issuer = `${opts.url.replace(/\/$/, '')}/auth/v1`;
    const verifyOpts = { issuer, audience: 'authenticated' };

    if (alg === 'HS256') {
      if (!opts.jwtSecret) return null;
      const { payload } = await jwtVerify(
        token,
        new TextEncoder().encode(opts.jwtSecret),
        { ...verifyOpts, algorithms: ['HS256'] },
      );
      return toAuthUser(payload);
    }

    if (alg === 'ES256' || alg === 'RS256') {
      const { payload } = await jwtVerify(token, opts.jwks ?? jwksFor(opts.url), {
        ...verifyOpts,
        algorithms: ['ES256', 'RS256'],
      });
      return toAuthUser(payload);
    }
    return null;
  } catch {
    return null;
  }
}
