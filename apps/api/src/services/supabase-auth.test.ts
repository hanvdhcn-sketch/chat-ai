import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { SignJWT, createLocalJWKSet, exportJWK, generateKeyPair } from 'jose';
import { authenticateBearer } from '../middleware/auth.js';
import { verifySupabaseJwt } from './supabase-auth.js';

const URL_ = 'https://proj.supabase.co';
const SECRET = 'super-secret-jwt-key-for-tests-0123456789';
const USER_ID = '0b6f5a54-3f2d-4d2b-9a3b-6a1c3f2f8e11';

async function hsToken(
  overrides: { issuer?: string; audience?: string; secret?: string; exp?: string } = {},
): Promise<string> {
  return new SignJWT({
    email: 'a@b.co',
    user_metadata: { full_name: 'Ada', locale: 'vi' },
  })
    .setProtectedHeader({ alg: 'HS256' })
    .setSubject(USER_ID)
    .setIssuer(overrides.issuer ?? `${URL_}/auth/v1`)
    .setAudience(overrides.audience ?? 'authenticated')
    .setIssuedAt()
    .setExpirationTime(overrides.exp ?? '1h')
    .sign(new TextEncoder().encode(overrides.secret ?? SECRET));
}

describe('verifySupabaseJwt', () => {
  it('accepts a valid HS256 Supabase token and maps claims', async () => {
    const user = await verifySupabaseJwt(await hsToken(), {
      url: URL_,
      jwtSecret: SECRET,
    });
    assert.equal(user?.id, USER_ID);
    assert.equal(user?.email, 'a@b.co');
    assert.equal(user?.name, 'Ada');
    assert.equal(user?.locale, 'vi');
    assert.equal(user?.planTier, 'free');
  });

  it('rejects wrong secret, issuer, audience and expired tokens', async () => {
    const opts = { url: URL_, jwtSecret: SECRET };
    assert.equal(
      await verifySupabaseJwt(await hsToken({ secret: 'other-secret-other-secret-other-1234' }), opts),
      null,
    );
    assert.equal(
      await verifySupabaseJwt(await hsToken({ issuer: 'https://evil.example/auth/v1' }), opts),
      null,
    );
    assert.equal(
      await verifySupabaseJwt(await hsToken({ audience: 'anon' }), opts),
      null,
    );
    assert.equal(await verifySupabaseJwt(await hsToken({ exp: '-1h' }), opts), null);
  });

  it('rejects HS256 when no secret is configured and alg=none', async () => {
    assert.equal(await verifySupabaseJwt(await hsToken(), { url: URL_ }), null);
    const none = `${Buffer.from('{"alg":"none"}').toString('base64url')}.${Buffer.from(
      JSON.stringify({ sub: USER_ID, aud: 'authenticated', iss: `${URL_}/auth/v1` }),
    ).toString('base64url')}.`;
    assert.equal(await verifySupabaseJwt(none, { url: URL_, jwtSecret: SECRET }), null);
  });

  it('accepts ES256 tokens verified through JWKS', async () => {
    const { publicKey, privateKey } = await generateKeyPair('ES256');
    const jwk = { ...(await exportJWK(publicKey)), alg: 'ES256', kid: 'k1' };
    const jwks = createLocalJWKSet({ keys: [jwk] });
    const token = await new SignJWT({ email: 'e@x.co' })
      .setProtectedHeader({ alg: 'ES256', kid: 'k1' })
      .setSubject(USER_ID)
      .setIssuer(`${URL_}/auth/v1`)
      .setAudience('authenticated')
      .setExpirationTime('1h')
      .sign(privateKey);
    const user = await verifySupabaseJwt(token, { url: URL_, jwks });
    assert.equal(user?.id, USER_ID);
    assert.equal(await verifySupabaseJwt(token + 'x', { url: URL_, jwks }), null);
  });
});

describe('authenticateBearer', () => {
  const supabase = { url: URL_, jwtSecret: SECRET };

  it('rejects stub tokens unless the dev flag is on', async () => {
    assert.equal(
      await authenticateBearer('stub:user_demo:pro', { allowDevStubAuth: false, supabase }),
      null,
    );
    const user = await authenticateBearer('stub:user_demo:pro', {
      allowDevStubAuth: true,
      supabase,
    });
    assert.equal(user?.id, 'user_demo');
    assert.equal(user?.planTier, 'pro');
  });

  it('verifies real tokens regardless of the dev flag', async () => {
    const user = await authenticateBearer(await hsToken(), {
      allowDevStubAuth: false,
      supabase,
    });
    assert.equal(user?.id, USER_ID);
  });
});
