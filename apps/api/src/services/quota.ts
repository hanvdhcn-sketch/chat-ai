import type { AuthUser } from '../types/index.js';
import { getOrCreateUsage } from './store.js';
import { config } from '../config.js';
import { effectiveImageLimits } from './quota-context.js';

export interface QuotaCheckResult {
  ok: boolean;
  reason?:
    | 'message_quota_exceeded'
    | 'token_soft_cap_exceeded'
    | 'image_quota_exceeded'
    | 'too_many_images_per_message';
  usage: ReturnType<typeof getOrCreateUsage>;
  rateLimitPerMin: number;
}

export function checkQuota(user: AuthUser): QuotaCheckResult {
  const usage = getOrCreateUsage(user.id, user.planTier);
  const rateLimitPerMin =
    user.planTier === 'pro'
      ? config.quotas.proRateLimitPerMin
      : config.quotas.freeRateLimitPerMin;

  if (usage.messagesCount >= usage.messagesLimit) {
    return { ok: false, reason: 'message_quota_exceeded', usage, rateLimitPerMin };
  }

  const tokensUsed = usage.inputTokens + usage.outputTokens;
  if (tokensUsed >= usage.tokenSoftCap) {
    return {
      ok: false,
      reason: 'token_soft_cap_exceeded',
      usage,
      rateLimitPerMin,
    };
  }

  return { ok: true, usage, rateLimitPerMin };
}

/** Enforce per-message + daily image hard quotas before streaming. */
export function checkImageQuota(
  user: AuthUser,
  imageCountInMessage: number,
): QuotaCheckResult {
  const base = checkQuota(user);
  const usage = base.usage;
  const limits = effectiveImageLimits(user.planTier, usage);

  if (imageCountInMessage <= 0) return base;

  if (imageCountInMessage > limits.maxImagesPerMessage) {
    return {
      ok: false,
      reason: 'too_many_images_per_message',
      usage,
      rateLimitPerMin: base.rateLimitPerMin,
    };
  }

  const used = usage.imagesCount ?? 0;
  const limit = usage.imagesLimit ?? limits.maxImagesPerDay;
  if (used + imageCountInMessage > limit) {
    return {
      ok: false,
      reason: 'image_quota_exceeded',
      usage,
      rateLimitPerMin: base.rateLimitPerMin,
    };
  }

  return base;
}
