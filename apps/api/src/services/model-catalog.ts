import type { PlanTier } from '../config.js';
import type { ModelId } from '../types/index.js';

/**
 * Logical model → xAI vendor API model id (overridable via env).
 *
 * Current xAI public chat lineup (docs.x.ai, Nov 2026):
 * - grok-4.3 — cheapest general chat ($1.25/$2.50); supports reasoning none
 * - grok-4.7 — flagship ($2/$6); stronger capability (reasoning cannot be disabled)
 * Legacy grok-3 / grok-3-mini are retired (redirect or 404) — do not use as defaults.
 */
export function vendorModelId(model: ModelId): string {
  switch (model) {
    case 'grok-fast':
      return process.env.XAI_GROK_FAST_MODEL ?? 'grok-4.3';
    case 'grok':
    default:
      return process.env.XAI_GROK_MODEL ?? 'grok-4.7';
  }
}

/**
 * Multimodal / image-attachment chats — Grok Fast (Free) and Grok both route here.
 * Override with XAI_GROK_VISION_MODEL. Default is a current vision-capable id
 * (legacy grok-2-vision-1212 was removed from xAI).
 * Left on flagship grok-4.7 for both tiers — Free text chat is the cheaper path.
 */
export function vendorVisionModelId(): string {
  return process.env.XAI_GROK_VISION_MODEL ?? 'grok-4.7';
}

/**
 * Free text chats on grok-4.3: disable reasoning for cost/latency.
 * Pro / vision / other models: leave vendor defaults (do not force effort).
 * Chat Completions uses `reasoning_effort`; Responses API uses `reasoning.effort`.
 */
export function vendorReasoningExtras(
  model: ModelId,
  apiModel: string,
): {
  chatCompletions?: { reasoning_effort: 'none' };
  responses?: { reasoning: { effort: 'none' } };
} {
  if (model !== 'grok-fast') return {};
  // Only apply when the resolved vendor id is a 4.3-family model that accepts "none".
  if (!/^grok-4\.3(\b|$|-)/.test(apiModel)) return {};
  return {
    chatCompletions: { reasoning_effort: 'none' },
    responses: { reasoning: { effort: 'none' } },
  };
}

/** Product-facing labels for system-prompt / FAQ facts (not vendor API ids). */
export function planModelFacts(planTier: PlanTier): {
  freeLabel: string;
  proLabel: string;
  freeVendorId: string;
  proVendorId: string;
  currentLabel: string;
  currentVendorId: string;
} {
  const freeVendorId = vendorModelId('grok-fast');
  const proVendorId = vendorModelId('grok');
  const freeLabel = 'Grok Fast (lighter / cheaper)';
  const proLabel = 'Grok (stronger)';
  return {
    freeLabel,
    proLabel,
    freeVendorId,
    proVendorId,
    currentLabel: planTier === 'pro' ? proLabel : freeLabel,
    currentVendorId: planTier === 'pro' ? proVendorId : freeVendorId,
  };
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
 * Free → Grok Fast (lighter/cheaper vendor model + quota-limited).
 * Pro → Grok (stronger vendor model by default); allow grok-fast when requested.
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
