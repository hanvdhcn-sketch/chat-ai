import type { PlanTier } from '../config.js';
import type { ModelId } from '../types/index.js';

/**
 * Recommended flagship stable Grok vendor id for Pro (`grok` logical id).
 *
 * xAI has no cross-family “always the absolute strongest” alias. Family aliases
 * (`grok-4.7`, `grok-4.7-latest`) only track within that family. When a newer
 * flagship ships (e.g. grok-4.8), Partner/ops bump without a code change by
 * setting `XAI_GROK_MODEL` and redeploying — or update this constant as the
 * documented default. Do not invent fake model ids.
 *
 * Current best known stable flagship (docs.x.ai, Nov 2026): grok-4.7
 * Prefer the bare family id (latest stable) over `-latest` (may include less stable).
 */
export const RECOMMENDED_FLAGSHIP_GROK_MODEL = 'grok-4.7';

/** Cheaper Free-tier text model (`grok-fast`). Override with `XAI_GROK_FAST_MODEL`. */
export const RECOMMENDED_FAST_GROK_MODEL = 'grok-4.3';

/**
 * Logical model → xAI vendor API model id (overridable via env).
 *
 * Current xAI public chat lineup (docs.x.ai, Nov 2026):
 * - grok-4.3 — cheaper general chat ($1.25/$2.50); supports reasoning none
 * - grok-4.7 — current flagship stable ($2/$6); stronger capability
 * Legacy grok-3 / grok-3-mini are retired (redirect or 404) — do not use as defaults.
 */
export function vendorModelId(model: ModelId): string {
  switch (model) {
    case 'grok-fast':
      return (
        process.env.XAI_GROK_FAST_MODEL?.trim() || RECOMMENDED_FAST_GROK_MODEL
      );
    case 'grok':
    default:
      return (
        process.env.XAI_GROK_MODEL?.trim() || RECOMMENDED_FLAGSHIP_GROK_MODEL
      );
  }
}

/**
 * Multimodal / image-attachment chats — Grok Fast (Free) and Grok both route here.
 * Override with XAI_GROK_VISION_MODEL. Default tracks the recommended flagship
 * (legacy grok-2-vision-1212 was removed from xAI).
 * Left on flagship for both tiers — Free text chat is the cheaper path.
 */
export function vendorVisionModelId(): string {
  return (
    process.env.XAI_GROK_VISION_MODEL?.trim() || RECOMMENDED_FLAGSHIP_GROK_MODEL
  );
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
  const proLabel = 'Grok (current strongest stable)';
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
 * Pro → Grok (current strongest stable vendor model by default); allow grok-fast when requested.
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
