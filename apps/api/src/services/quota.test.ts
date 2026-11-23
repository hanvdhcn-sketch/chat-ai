import assert from 'node:assert/strict';
import { describe, it, beforeEach } from 'node:test';
import { checkImageQuota, checkQuota } from './quota.js';
import { resetStore, setUsageForTests, getOrCreateUsage } from './store.js';
import { checkRateLimit, resetRateLimits } from './rate-limit.js';
import type { AuthUser } from '../types/index.js';

const freeUser: AuthUser = {
  id: 'u_free',
  email: 'f@example.com',
  locale: 'en',
  planTier: 'free',
};

const proUser: AuthUser = {
  id: 'u_pro',
  email: 'p@example.com',
  locale: 'en',
  planTier: 'pro',
};

describe('quota + rate limit', () => {
  beforeEach(() => {
    resetStore();
    resetRateLimits();
  });

  it('allows under message quota', () => {
    const r = checkQuota(freeUser);
    assert.equal(r.ok, true);
    assert.equal(r.usage.messagesLimit, 100);
  });

  it('blocks when message hard quota exceeded', () => {
    const snap = getOrCreateUsage(freeUser.id, 'free');
    snap.messagesCount = snap.messagesLimit;
    setUsageForTests(snap);
    const r = checkQuota(freeUser);
    assert.equal(r.ok, false);
    assert.equal(r.reason, 'message_quota_exceeded');
  });

  it('blocks when token soft-cap exceeded', () => {
    const snap = getOrCreateUsage(freeUser.id, 'free');
    snap.inputTokens = snap.tokenSoftCap;
    setUsageForTests(snap);
    const r = checkQuota(freeUser);
    assert.equal(r.ok, false);
    assert.equal(r.reason, 'token_soft_cap_exceeded');
  });

  it('blocks too many images per Free message', () => {
    const r = checkImageQuota(freeUser, 4);
    assert.equal(r.ok, false);
    assert.equal(r.reason, 'too_many_images_per_message');
  });

  it('blocks when daily image quota would be exceeded', () => {
    const snap = getOrCreateUsage(freeUser.id, 'free');
    snap.imagesCount = snap.imagesLimit - 1;
    setUsageForTests(snap);
    const r = checkImageQuota(freeUser, 2);
    assert.equal(r.ok, false);
    assert.equal(r.reason, 'image_quota_exceeded');
  });

  it('rate-limits after N hits per minute', () => {
    const now = Date.now();
    for (let i = 0; i < 5; i++) {
      assert.equal(checkRateLimit('u1', 5, now + i).ok, true);
    }
    assert.equal(checkRateLimit('u1', 5, now + 10).ok, false);
  });

  it('allows Pro 8 images per message before monthly soft-cap', () => {
    const r = checkImageQuota(proUser, 8);
    assert.equal(r.ok, true);
  });

  it('reduces Pro to Free per-message image cap after monthly soft-cap', () => {
    const snap = getOrCreateUsage(proUser.id, 'pro');
    snap.monthImagesCount = 200;
    setUsageForTests(snap);
    const r = checkImageQuota(proUser, 4);
    assert.equal(r.ok, false);
    assert.equal(r.reason, 'too_many_images_per_message');
    const ok = checkImageQuota(proUser, 3);
    assert.equal(ok.ok, true);
  });
});
