import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  buildOrbitaQuotaSystemPrompt,
  imageLimitsForPlan,
  quotaResetsAtIso,
} from './quota-context.js';
import type { UsageSnapshot } from '../types/index.js';

const freeUsage: UsageSnapshot = {
  userId: 'u1',
  window: 'day',
  windowStart: '2026-11-23T00:00:00.000Z',
  messagesCount: 3,
  messagesLimit: 100,
  imagesCount: 2,
  imagesLimit: 20,
  inputTokens: 0,
  outputTokens: 0,
  tokenSoftCap: 80_000,
  planTier: 'free',
};

describe('quota-context', () => {
  it('reports Free image limits', () => {
    const lim = imageLimitsForPlan('free');
    assert.equal(lim.maxImagesPerMessage, 3);
    assert.equal(lim.maxImagesPerDay, 20);
    assert.equal(lim.maxImageBytes, 8 * 1024 * 1024);
  });

  it('reports Pro image limits', () => {
    const lim = imageLimitsForPlan('pro');
    assert.equal(lim.maxImagesPerMessage, 5);
    assert.equal(lim.maxImagesPerDay, 100);
  });

  it('computes next UTC midnight reset', () => {
    assert.equal(
      quotaResetsAtIso('2026-11-23T00:00:00.000Z'),
      '2026-11-24T00:00:00.000Z',
    );
  });

  it('injects Orbita quota facts into system prompt', () => {
    const prompt = buildOrbitaQuotaSystemPrompt(freeUsage, 'free');
    assert.match(prompt, /Orbita/);
    assert.match(prompt, /Free/);
    assert.match(prompt, /100 daily limit/);
    assert.match(prompt, /97 remaining/);
    assert.match(prompt, /20 images per day/);
    assert.match(prompt, /never xAI\.com/);
    assert.match(prompt, /Grok\.com Premium/);
    assert.match(prompt, /not xAI\/Grok\.com|never .*SuperGrok|never xAI/i);
  });
});
