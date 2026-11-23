import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  buildOrbitaQuotaSystemPrompt,
  effectiveImageLimits,
  imageLimitsForPlan,
  isProMonthlyImageSoftCapActive,
  monthResetsAtIso,
  monthlyImageSoftCapStatus,
  quotaResetsAtIso,
  resolveQuotaPromptLocale,
} from './quota-context.js';
import type { UsageSnapshot } from '../types/index.js';

const freeUsage: UsageSnapshot = {
  userId: 'u1',
  window: 'day',
  windowStart: '2026-11-23T00:00:00.000Z',
  messagesCount: 3,
  messagesLimit: 100,
  imagesCount: 2,
  imagesLimit: 10,
  monthImagesCount: 2,
  monthWindowStart: '2026-11-01T00:00:00.000Z',
  inputTokens: 0,
  outputTokens: 0,
  tokenSoftCap: 80_000,
  planTier: 'free',
};

describe('quota-context', () => {
  it('reports Free image limits', () => {
    const lim = imageLimitsForPlan('free');
    assert.equal(lim.maxImagesPerMessage, 3);
    assert.equal(lim.maxImagesPerDay, 10);
    assert.equal(lim.maxImageBytes, 8 * 1024 * 1024);
  });

  it('reports Pro image limits', () => {
    const lim = imageLimitsForPlan('pro');
    assert.equal(lim.maxImagesPerMessage, 8);
    assert.equal(lim.maxImagesPerDay, 20);
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
    assert.match(prompt, /10 images per day/);
    assert.match(prompt, /ALWAYS reply in the same language/);
    assert.match(prompt, /never xAI\.com/);
    assert.match(prompt, /Grok\.com Premium/);
    assert.match(prompt, /not xAI\/Grok\.com|never .*SuperGrok|never xAI/i);
    assert.doesNotMatch(prompt, /soft-cap|monthly image allowance/i);
  });

  it('detects Vietnamese from latest user message', () => {
    assert.equal(
      resolveQuotaPromptLocale({ latestUserMessage: 'dịch tiếng việt' }),
      'vi',
    );
    assert.equal(resolveQuotaPromptLocale({ locale: 'vi' }), 'vi');
    assert.equal(
      resolveQuotaPromptLocale({
        locale: 'en',
        latestUserMessage: 'how many messages left?',
      }),
      'en',
    );
  });

  it('localizes quota system prompt to Vietnamese', () => {
    const prompt = buildOrbitaQuotaSystemPrompt(freeUsage, 'free', {
      latestUserMessage: 'dịch tiếng việt',
    });
    assert.match(prompt, /LUÔN trả lời bằng ngôn ngữ/);
    assert.match(prompt, /Gói Orbita hiện tại: Miễn phí/);
    assert.match(prompt, /10 ảnh\/ngày/);
    assert.match(prompt, /không nêu xAI\.com/);
    assert.doesNotMatch(prompt, /ALWAYS reply in the same language/);
  });

  it('activates Pro monthly image soft-cap at 200', () => {
    assert.equal(isProMonthlyImageSoftCapActive({ monthImagesCount: 199 }, 'pro'), false);
    assert.equal(isProMonthlyImageSoftCapActive({ monthImagesCount: 200 }, 'pro'), true);
    assert.equal(isProMonthlyImageSoftCapActive({ monthImagesCount: 250 }, 'free'), false);
  });

  it('reduces Pro image limits to Free while soft-cap is active', () => {
    const lim = effectiveImageLimits('pro', { monthImagesCount: 200 });
    assert.equal(lim.maxImagesPerMessage, 3);
    assert.equal(lim.maxImagesPerDay, 10);
    const status = monthlyImageSoftCapStatus(
      {
        ...freeUsage,
        userId: 'u_pro',
        planTier: 'pro',
        messagesLimit: 400,
        monthImagesCount: 200,
        monthWindowStart: '2026-11-01T00:00:00.000Z',
      },
      'pro',
    );
    assert.ok(status);
    assert.equal(status?.effectiveImageTier, 'free');
    assert.equal(status?.resetsAt, '2026-12-01T00:00:00.000Z');
  });

  it('computes next UTC month reset', () => {
    assert.equal(
      monthResetsAtIso('2026-11-01T00:00:00.000Z'),
      '2026-12-01T00:00:00.000Z',
    );
  });

  it('mentions temporary Free image rates only when soft-cap is active', () => {
    const prompt = buildOrbitaQuotaSystemPrompt(
      {
        ...freeUsage,
        userId: 'u_pro',
        planTier: 'pro',
        messagesLimit: 400,
        monthImagesCount: 200,
        monthWindowStart: '2026-11-01T00:00:00.000Z',
      },
      'pro',
    );
    assert.match(prompt, /temporarily limited to Free-tier/);
    assert.match(prompt, /2026-12-01/);
  });
});
