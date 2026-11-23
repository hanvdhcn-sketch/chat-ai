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
  messagesLimit: 60,
  imagesCount: 2,
  imagesLimit: 8,
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
    assert.equal(lim.maxImagesPerDay, 8);
    assert.equal(lim.maxImageBytes, 5 * 1024 * 1024);
  });

  it('reports Pro image limits', () => {
    const lim = imageLimitsForPlan('pro');
    assert.equal(lim.maxImagesPerMessage, 8);
    assert.equal(lim.maxImagesPerDay, 20);
    assert.equal(lim.maxImageBytes, 8 * 1024 * 1024);
  });

  it('computes next UTC midnight reset', () => {
    assert.equal(
      quotaResetsAtIso('2026-11-23T00:00:00.000Z'),
      '2026-11-24T00:00:00.000Z',
    );
  });

  it('injects Orbita quota facts into system prompt', () => {
    const prompt = buildOrbitaQuotaSystemPrompt(freeUsage, 'free', {
      now: new Date('2026-11-23T08:33:05.000Z'),
    });
    assert.match(prompt, /Orbita/);
    assert.match(prompt, /Free/);
    assert.match(prompt, /60 daily limit/);
    assert.match(prompt, /57 remaining/);
    assert.match(prompt, /8 images per day/);
    assert.match(prompt, /max 5 MB each/);
    assert.match(prompt, /≤5 MB/);
    assert.match(prompt, /≤8 MB/);
    assert.match(prompt, /ALWAYS reply in the same language/);
    assert.match(prompt, /search the live web via tools/i);
    assert.match(prompt, /do NOT use web search to learn the current time/i);
    assert.match(prompt, /Current time \(API host clock/);
    assert.match(prompt, /15:33:05/);
    assert.match(prompt, /Web search counts as a normal Orbita chat message/);
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
      now: new Date('2026-11-23T08:33:05.000Z'),
    });
    assert.match(prompt, /LUÔN trả lời bằng ngôn ngữ/);
    assert.match(prompt, /tìm kiếm web qua công cụ/i);
    assert.match(prompt, /KHÔNG dùng web search để biết giờ hiện tại/);
    assert.match(prompt, /Thời gian hiện tại/);
    assert.match(prompt, /15:33:05/);
    assert.match(prompt, /Gói Orbita hiện tại: Miễn phí/);
    assert.match(prompt, /8 ảnh\/ngày/);
    assert.match(prompt, /mỗi ảnh tối đa 5 MB/);
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
    assert.equal(lim.maxImagesPerDay, 8);
    assert.equal(lim.maxImageBytes, 5 * 1024 * 1024);
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
