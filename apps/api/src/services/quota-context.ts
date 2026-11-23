import type { PlanTier } from '../config.js';
import { config } from '../config.js';
import type { UsageSnapshot } from '../types/index.js';

export interface ImageQuotaLimits {
  maxImagesPerMessage: number;
  maxImageBytes: number;
  maxImagesPerDay: number;
}

export function imageLimitsForPlan(planTier: PlanTier): ImageQuotaLimits {
  if (planTier === 'pro') {
    return {
      maxImagesPerMessage: config.quotas.proImagesPerMessage,
      maxImageBytes: config.quotas.maxImageBytes,
      maxImagesPerDay: config.quotas.proImagesPerDay,
    };
  }
  return {
    maxImagesPerMessage: config.quotas.freeImagesPerMessage,
    maxImageBytes: config.quotas.maxImageBytes,
    maxImagesPerDay: config.quotas.freeImagesPerDay,
  };
}

/** Next UTC midnight after the current usage window start. */
export function quotaResetsAtIso(windowStart: string): string {
  const d = new Date(windowStart);
  if (Number.isNaN(d.getTime())) {
    const fallback = new Date();
    fallback.setUTCHours(24, 0, 0, 0);
    return fallback.toISOString();
  }
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString();
}

/**
 * System prompt fragment so Grok answers with Orbita app quotas — not xAI/Grok.com.
 * Injected each request with live remaining counts.
 */
export function buildOrbitaQuotaSystemPrompt(
  usage: UsageSnapshot,
  planTier: PlanTier,
): string {
  const images = imageLimitsForPlan(planTier);
  const messagesRemaining = Math.max(0, usage.messagesLimit - usage.messagesCount);
  const imagesRemaining = Math.max(
    0,
    (usage.imagesLimit ?? images.maxImagesPerDay) -
      (usage.imagesCount ?? 0),
  );
  const resetsAt = quotaResetsAtIso(usage.windowStart);
  const maxMb = Math.round(images.maxImageBytes / (1024 * 1024));
  const planLabel = planTier === 'pro' ? 'Pro' : 'Free';

  return [
    'You are Orbita, a Windows desktop chat app powered by xAI Grok.',
    'When users ask about message limits, quotas, plans, upgrades, remaining messages, resets, or image upload limits, answer ONLY with Orbita app quotas below — never xAI.com, Grok.com Premium, SuperGrok, or other vendor plans.',
    '',
    `Current Orbita plan: ${planLabel}`,
    `Messages today: ${usage.messagesCount} used / ${usage.messagesLimit} daily limit (${messagesRemaining} remaining).`,
    `Quota window: calendar day UTC; resets at ${resetsAt}.`,
    `Image uploads: up to ${images.maxImagesPerMessage} image(s) per message, max ${maxMb} MB each; ${usage.imagesCount ?? 0} used / ${usage.imagesLimit ?? images.maxImagesPerDay} images per day (${imagesRemaining} remaining today).`,
    planTier === 'free'
      ? 'Free users can upgrade to Orbita Pro (Microsoft Store) for a higher daily message and image allowance.'
      : 'Pro includes higher daily message and image allowances than Free.',
  ].join('\n');
}
