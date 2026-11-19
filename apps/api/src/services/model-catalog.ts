import type { PlanTier } from '../config.js';
import type { ModelId } from '../types/index.js';

/** Logical model → vendor API model id (overridable via env). */
export function vendorModelId(model: ModelId): string {
  switch (model) {
    case 'gemini-flash':
      return process.env.GEMINI_FLASH_MODEL ?? 'gemini-2.0-flash';
    case 'gemini-pro':
      return process.env.GEMINI_PRO_MODEL ?? 'gemini-2.0-flash';
    case 'grok-fast':
      return process.env.XAI_GROK_FAST_MODEL ?? 'grok-3-mini';
    case 'grok':
    default:
      return process.env.XAI_GROK_MODEL ?? 'grok-3';
  }
}

export function isGrokModel(model: ModelId): boolean {
  return model === 'grok' || model === 'grok-fast';
}

export function isGeminiModel(model: ModelId): boolean {
  return model === 'gemini-flash' || model === 'gemini-pro';
}

/**
 * Free → Gemini Flash only (ignore client request for Grok).
 * Pro → Grok default; allow Gemini Flash/Pro and Grok variants.
 */
export function resolveModel(
  planTier: PlanTier,
  requested?: ModelId,
): ModelId {
  if (planTier === 'free') {
    return 'gemini-flash';
  }
  if (
    requested === 'gemini-flash' ||
    requested === 'gemini-pro' ||
    requested === 'grok-fast' ||
    requested === 'grok'
  ) {
    return requested;
  }
  return 'grok';
}

/** Same cost-band fallback when primary vendor fails. */
export function fallbackModel(model: ModelId): ModelId | null {
  if (isGeminiModel(model)) return 'grok-fast';
  if (isGrokModel(model)) return 'gemini-flash';
  return null;
}
