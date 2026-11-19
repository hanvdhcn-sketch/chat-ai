import { config, isAiConfigured } from '../config.js';
import type { PlanTier } from '../config.js';
import type { ModelId } from '../types/index.js';

export interface ChatTurn {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

export interface StreamChunk {
  type: 'delta' | 'done' | 'error';
  text?: string;
  model?: ModelId;
  inputTokens?: number;
  outputTokens?: number;
  error?: string;
}

/**
 * Resolve model for tier. Free → Gemini Flash only; Pro → Grok default + Gemini.
 * No Anthropic/Claude. Cursor is not a runtime.
 */
export function resolveModel(
  planTier: PlanTier,
  requested?: ModelId,
): ModelId {
  if (planTier === 'free') {
    return 'gemini-flash';
  }
  if (requested === 'gemini-flash' || requested === 'gemini-pro') {
    return requested;
  }
  return requested === 'grok-fast' ? 'grok-fast' : 'grok';
}

/**
 * AI gateway stub. When XAI_API_KEY / GOOGLE_GEMINI_API_KEY are set,
 * wire official SDKs here. Until then, yields a deterministic stub stream.
 */
export async function* streamCompletion(opts: {
  planTier: PlanTier;
  model?: ModelId;
  messages: ChatTurn[];
  abortSignal?: AbortSignal;
}): AsyncGenerator<StreamChunk> {
  const model = resolveModel(opts.planTier, opts.model);
  const lastUser =
    [...opts.messages].reverse().find((m) => m.role === 'user')?.content ??
    '';

  if (!isAiConfigured()) {
    const stub =
      `[ChatAI stub · ${model}] Keys not configured. ` +
      `Set XAI_API_KEY and/or GOOGLE_GEMINI_API_KEY on the server. ` +
      `Echo: ${lastUser.slice(0, 200)}`;
    for (const word of stub.split(' ')) {
      if (opts.abortSignal?.aborted) {
        yield { type: 'error', error: 'aborted', model };
        return;
      }
      yield { type: 'delta', text: `${word} `, model };
      await sleep(20);
    }
    yield {
      type: 'done',
      model,
      inputTokens: Math.ceil(lastUser.length / 4),
      outputTokens: Math.ceil(stub.length / 4),
    };
    return;
  }

  // Production path placeholder — call xAI or Gemini streaming APIs.
  // Free: Gemini Flash. Pro: Grok (default) or Gemini Pro/Flash.
  void config.ai;
  yield {
    type: 'error',
    error:
      'ai_keys_present_but_sdk_not_wired_yet — implement vendor stream in ai-gateway.ts',
    model,
  };
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}
