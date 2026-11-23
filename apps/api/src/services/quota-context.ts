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

export type QuotaPromptLocale = 'vi' | 'en';

export interface QuotaPromptOptions {
  /** App / account locale when known. */
  locale?: QuotaPromptLocale | string;
  /** Latest user message text — used to follow the user's language. */
  latestUserMessage?: string;
}

const VI_CHAR_RE =
  /[àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ]/i;
const VI_PHRASE_RE =
  /\b(tiếng\s*việt|tieng\s*viet|dịch|dich|xin\s*chào|cảm\s*ơn|cam\s*on|vui\s*lòng|cho\s*mình|hôm\s*nay)\b/i;

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

/** Prefer Vietnamese when locale is vi or the latest user message is Vietnamese. */
export function resolveQuotaPromptLocale(
  options?: QuotaPromptOptions,
): QuotaPromptLocale {
  const msg = options?.latestUserMessage?.trim() ?? '';
  if (msg && (VI_CHAR_RE.test(msg) || VI_PHRASE_RE.test(msg))) {
    return 'vi';
  }
  const loc = (options?.locale ?? '').toLowerCase();
  if (loc.startsWith('vi')) return 'vi';
  return 'en';
}

/**
 * System prompt fragment so Grok answers with Orbita app quotas — never xAI/Grok.com.
 * Always instructs the model to reply in the user's language (match latest message).
 * Monthly soft-cap is mentioned only when already active (not marketed).
 */
export function buildOrbitaQuotaSystemPrompt(
  usage: UsageSnapshot,
  planTier: PlanTier,
  options?: QuotaPromptOptions,
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
  const softCap = monthlyImageSoftCapStatus(usage, planTier);
  const locale = resolveQuotaPromptLocale(options);
  const freePlan = imageLimitsForPlan('free');
  const proPlan = imageLimitsForPlan('pro');

  if (locale === 'vi') {
    const planLabel = planTier === 'pro' ? 'Pro' : 'Miễn phí';
    const lines = [
      'Bạn là Orbita, ứng dụng chat máy tính Windows chạy trên xAI Grok.',
      'LUÔN trả lời bằng ngôn ngữ của tin nhắn người dùng gần nhất (ví dụ tiếng Việt → trả lời tiếng Việt). Không dùng mẫu tiếng Anh cố định khi người dùng viết tiếng Việt.',
      'Khi nói về hạn mức tin nhắn, quota, gói, nâng cấp, số tin còn lại, thời điểm reset, hoặc giới hạn tải ảnh: chỉ dùng số liệu Orbita bên dưới — không nêu xAI.com, Grok.com Premium, SuperGrok hay gói vendor khác. Dịch các số liệu này sang ngôn ngữ người dùng; giữ đúng con số.',
      '',
      `Gói Orbita hiện tại: ${planLabel}`,
      `Tin nhắn hôm nay: đã dùng ${usage.messagesCount} / hạn mức ${usage.messagesLimit} tin/ngày (còn ${messagesRemaining}).`,
      `Cửa sổ quota: theo ngày lịch UTC; đặt lại lúc ${resetsAt}.`,
      `Tải ảnh: tối đa ${images.maxImagesPerMessage} ảnh/tin, mỗi ảnh tối đa ${maxMb} MB; đã dùng ${usage.imagesCount ?? 0} / ${usage.imagesLimit ?? images.maxImagesPerDay} ảnh/ngày (còn ${imagesRemaining} hôm nay).`,
      `Tham chiếu gói: Miễn phí ${config.quotas.freeMessagesPerDay} tin/ngày, ${freePlan.maxImagesPerMessage} ảnh/tin, ${freePlan.maxImagesPerDay} ảnh/ngày; Pro ${config.quotas.proMessagesPerDay} tin/ngày, ${proPlan.maxImagesPerMessage} ảnh/tin, ${proPlan.maxImagesPerDay} ảnh/ngày; mỗi ảnh tối đa ${maxMb} MB.`,
    ];

    if (softCap) {
      lines.push(
        `Tải ảnh tạm thời theo hạn mức Miễn phí trong tháng này (đặt lại ${softCap.resetsAt}); chat văn bản không bị ảnh hưởng. Không mô tả đây là tính năng Pro được quảng cáo — chỉ giải thích nếu người dùng hỏi vì sao giới hạn ảnh giảm.`,
      );
    } else if (planTier === 'free') {
      lines.push(
        'Người dùng Miễn phí có thể nâng cấp Orbita Pro (Microsoft Store) để có hạn mức tin nhắn và ảnh/ngày cao hơn.',
      );
    } else {
      lines.push(
        'Pro có hạn mức tin nhắn và ảnh/ngày cao hơn gói Miễn phí.',
      );
    }

    return lines.join('\n');
  }

  const planLabel = planTier === 'pro' ? 'Pro' : 'Free';
  const lines = [
    'You are Orbita, a Windows desktop chat app powered by xAI Grok.',
    "ALWAYS reply in the same language as the user's latest message (e.g. Vietnamese → reply in Vietnamese). Do not dump a fixed English template when the user writes in another language.",
    'When users ask about message limits, quotas, plans, upgrades, remaining messages, resets, or image upload limits, answer ONLY with Orbita app quotas below — never xAI.com, Grok.com Premium, SuperGrok, or other vendor plans. Translate these facts into the user\'s language; keep the numbers accurate.',
    '',
    `Current Orbita plan: ${planLabel}`,
    `Messages today: ${usage.messagesCount} used / ${usage.messagesLimit} daily limit (${messagesRemaining} remaining).`,
    `Quota window: calendar day UTC; resets at ${resetsAt}.`,
    `Image uploads: up to ${images.maxImagesPerMessage} image(s) per message, max ${maxMb} MB each; ${usage.imagesCount ?? 0} used / ${usage.imagesLimit ?? images.maxImagesPerDay} images per day (${imagesRemaining} remaining today).`,
    `Plan reference: Free ${config.quotas.freeMessagesPerDay} messages/day, ${freePlan.maxImagesPerMessage} images/message, ${freePlan.maxImagesPerDay} images/day; Pro ${config.quotas.proMessagesPerDay} messages/day, ${proPlan.maxImagesPerMessage} images/message, ${proPlan.maxImagesPerDay} images/day; max ${maxMb} MB per image.`,
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
