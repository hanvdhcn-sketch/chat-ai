import type { PlanTier } from '../config.js';
import { config } from '../config.js';
import type { UsageSnapshot } from '../types/index.js';

export interface ImageQuotaLimits {
  maxImagesPerMessage: number;
  maxImageBytes: number;
  maxImagesPerDay: number;
}

export interface MonthlyImageSoftCapStatus {
  active: true;
  monthImagesCount: number;
  softCap: number;
  resetsAt: string;
  /** Effective image tier while soft-cap is active. */
  effectiveImageTier: 'free';
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

/** Hidden Pro monthly soft-cap (~200 images / UTC month). */
export function isProMonthlyImageSoftCapActive(
  usage: Pick<UsageSnapshot, 'monthImagesCount'> | undefined,
  planTier: PlanTier,
): boolean {
  if (planTier !== 'pro') return false;
  const used = usage?.monthImagesCount ?? 0;
  return used >= config.quotas.proImagesPerMonthSoftCap;
}

/** Next UTC month start after the given month window (or now). */
export function monthResetsAtIso(monthWindowStart?: string): string {
  const d = monthWindowStart ? new Date(monthWindowStart) : new Date();
  if (Number.isNaN(d.getTime())) {
    const now = new Date();
    return new Date(
      Date.UTC(now.getUTCFullYear(), now.getUTCMonth() + 1, 1),
    ).toISOString();
  }
  return new Date(
    Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + 1, 1),
  ).toISOString();
}

/**
 * Effective image limits for enforcement / client UI.
 * Pro under monthly soft-cap → Free image rates until next month.
 */
export function effectiveImageLimits(
  planTier: PlanTier,
  usage?: Pick<UsageSnapshot, 'monthImagesCount'>,
): ImageQuotaLimits {
  if (isProMonthlyImageSoftCapActive(usage, planTier)) {
    return imageLimitsForPlan('free');
  }
  return imageLimitsForPlan(planTier);
}

export function monthlyImageSoftCapStatus(
  usage: UsageSnapshot,
  planTier: PlanTier,
): MonthlyImageSoftCapStatus | undefined {
  if (!isProMonthlyImageSoftCapActive(usage, planTier)) return undefined;
  return {
    active: true,
    monthImagesCount: usage.monthImagesCount ?? 0,
    softCap: config.quotas.proImagesPerMonthSoftCap,
    resetsAt: monthResetsAtIso(usage.monthWindowStart),
    effectiveImageTier: 'free',
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
 * System prompt fragment so Grok answers with Orbita app quotas — never xAI/Grok.com.
 * Monthly soft-cap is mentioned only when already active (not marketed).
 */
export function buildOrbitaQuotaSystemPrompt(
  usage: UsageSnapshot,
  planTier: PlanTier,
): string {
  const images = effectiveImageLimits(planTier, usage);
  const messagesRemaining = Math.max(0, usage.messagesLimit - usage.messagesCount);
  const imagesRemaining = Math.max(
    0,
    (usage.imagesLimit ?? images.maxImagesPerDay) -
      (usage.imagesCount ?? 0),
  );
  const resetsAt = quotaResetsAtIso(usage.windowStart);
  const maxMb = Math.round(images.maxImageBytes / (1024 * 1024));
  const planLabel = planTier === 'pro' ? 'Pro' : 'Free';
  const softCap = monthlyImageSoftCapStatus(usage, planTier);

  const lines = [
    'You are Orbita, a Windows desktop chat app powered by xAI Grok.',
    'When users ask about message limits, quotas, plans, upgrades, remaining messages, resets, or image upload limits, answer ONLY with Orbita app quotas below — never xAI.com, Grok.com Premium, SuperGrok, or other vendor plans.',
    '',
    `Current Orbita plan: ${planLabel}`,
    `Messages today: ${usage.messagesCount} used / ${usage.messagesLimit} daily limit (${messagesRemaining} remaining).`,
    `Quota window: calendar day UTC; resets at ${resetsAt}.`,
    `Image uploads: up to ${images.maxImagesPerMessage} image(s) per message, max ${maxMb} MB each; ${usage.imagesCount ?? 0} used / ${usage.imagesLimit ?? images.maxImagesPerDay} images per day (${imagesRemaining} remaining today).`,
  ];

  if (softCap) {
    lines.push(
      `Image uploads are temporarily limited to Free-tier rates this month (resets ${softCap.resetsAt}); text chat is unaffected. Do not describe this as a marketed Pro feature — only explain if the user asks why image limits dropped.`,
    );
  } else if (planTier === 'free') {
    lines.push(
      'Free users can upgrade to Orbita Pro (Microsoft Store) for a higher daily message and image allowance.',
    );
  } else {
    lines.push(
      'Pro includes higher daily message and image allowances than Free.',
    );
  }

  return lines.join('\n');
}
