import type { PlanTier } from '../config.js';
import type { ModelId } from '../types/index.js';

/** Logical model → xAI vendor API model id (overridable via env). */
export function vendorModelId(model: ModelId): string {
  switch (model) {
    case 'grok-fast':
      return process.env.XAI_GROK_FAST_MODEL ?? 'grok-3-mini';
    case 'grok':
    default:
      return process.env.XAI_GROK_MODEL ?? 'grok-3';
  }
}

/**
 * Multimodal / image-attachment chats — Grok Fast (Free) and Grok both route here.
 * Override with XAI_GROK_VISION_MODEL. Default is a current vision-capable id
 * (legacy grok-2-vision-1212 was removed from xAI).
 */
export function vendorVisionModelId(): string {
  return process.env.XAI_GROK_VISION_MODEL ?? 'grok-4.7';
}

export function isGrokModel(model: ModelId): boolean {
  return model === 'grok' || model === 'grok-fast';
}

/**
 * Normalize legacy client/DB model ids (Gemini-era) onto Grok.
 */
export function coerceModelId(raw?: string | null): ModelId | undefined {
  if (!raw) return undefined;
  if (raw === 'grok' || raw === 'grok-fast') return raw;
  if (raw === 'gemini-flash' || raw === 'gemini-pro') return 'grok-fast';
  return undefined;
}

/**
 * Free → Grok Fast (quota-limited).
 * Pro → Grok (default); allow grok-fast when requested.
 * Pro upgrade = full Grok API path.
 */
export function resolveModel(
  planTier: PlanTier,
  requested?: ModelId,
): ModelId {
  if (planTier === 'free') {
    return 'grok-fast';
  }
  if (requested === 'grok-fast' || requested === 'grok') {
    return requested;
  }
  return 'grok';
}

/** No cross-vendor fallback — Grok only. */
export function fallbackModel(_model: ModelId): ModelId | null {
  return null;
}
