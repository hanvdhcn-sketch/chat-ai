import type { AuthUser } from '../types/index.js';
import { getOrCreateUsage } from './store.js';
import { config } from '../config.js';

export interface QuotaCheckResult {
  ok: boolean;
  reason?: 'message_quota_exceeded' | 'token_soft_cap_exceeded';
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
