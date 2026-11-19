import { config } from '../config.js';
import type { PlanTier } from '../config.js';
import type { ModelId } from '../types/index.js';
import {
  fallbackModel,
  isGeminiModel,
  isGrokModel,
  resolveModel,
  vendorModelId,
} from './model-catalog.js';

export type { ModelId };
export { resolveModel } from './model-catalog.js';

export interface ChatTurn {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

export interface StreamChunk {
  type: 'delta' | 'done' | 'error' | 'meta';
  text?: string;
  model?: ModelId;
  inputTokens?: number;
  outputTokens?: number;
  error?: string;
  stub?: boolean;
  vendor?: 'xai' | 'gemini' | 'stub';
}

export type FetchLike = typeof fetch;

export interface GatewayDeps {
  fetchFn?: FetchLike;
  xaiApiKey?: string;
  geminiApiKey?: string;
  xaiBaseUrl?: string;
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

function estimateTokens(text: string): number {
  return Math.max(1, Math.ceil(text.length / 4));
}

function resolveKeys(deps: GatewayDeps) {
  return {
    xaiApiKey: deps.xaiApiKey ?? config.ai.xaiApiKey,
    geminiApiKey: deps.geminiApiKey ?? config.ai.geminiApiKey,
    xaiBaseUrl: deps.xaiBaseUrl ?? config.ai.xaiBaseUrl,
  };
}

async function* stubStream(
  model: ModelId,
  lastUser: string,
  abortSignal?: AbortSignal,
): AsyncGenerator<StreamChunk> {
  const stub =
    `[ChatAI stub · ${model}] Keys not configured for this route. ` +
    `Set XAI_API_KEY and/or GOOGLE_GEMINI_API_KEY on the server. ` +
    `Echo: ${lastUser.slice(0, 200)}`;
  yield { type: 'meta', model, stub: true, vendor: 'stub' };
  for (const word of stub.split(' ')) {
    if (abortSignal?.aborted) {
      yield { type: 'error', error: 'aborted', model, stub: true };
      return;
    }
    yield { type: 'delta', text: `${word} `, model, vendor: 'stub' };
    await sleep(12);
  }
  yield {
    type: 'done',
    model,
    stub: true,
    vendor: 'stub',
    inputTokens: estimateTokens(lastUser),
    outputTokens: estimateTokens(stub),
  };
}

function keyAvailableFor(
  model: ModelId,
  keys: ReturnType<typeof resolveKeys>,
): boolean {
  if (isGrokModel(model)) return Boolean(keys.xaiApiKey);
  if (isGeminiModel(model)) return Boolean(keys.geminiApiKey);
  return false;
}

function anyKey(keys: ReturnType<typeof resolveKeys>): boolean {
  return Boolean(keys.xaiApiKey || keys.geminiApiKey);
}

/**
 * Stream completion from Grok (xAI) or Gemini.
 * Missing keys → clear stub stream (no crash).
 * Primary vendor failure → one fallback attempt on the other vendor when keyed.
 */
export async function* streamCompletion(
  opts: {
    planTier: PlanTier;
    model?: ModelId;
    messages: ChatTurn[];
    abortSignal?: AbortSignal;
  },
  deps: GatewayDeps = {},
): AsyncGenerator<StreamChunk> {
  const fetchFn = deps.fetchFn ?? fetch;
  const keys = resolveKeys(deps);
  let model = resolveModel(opts.planTier, opts.model);
  const lastUser =
    [...opts.messages].reverse().find((m) => m.role === 'user')?.content ?? '';

  if (!keyAvailableFor(model, keys)) {
    const alt = fallbackModel(model);
    if (alt && keyAvailableFor(alt, keys) && opts.planTier === 'pro') {
      model = alt;
    } else if (!anyKey(keys) || !keyAvailableFor(model, keys)) {
      if (!keyAvailableFor(model, keys)) {
        yield* stubStream(model, lastUser, opts.abortSignal);
        return;
      }
    }
  }

  try {
    if (isGrokModel(model)) {
      yield* streamXai({
        model,
        messages: opts.messages,
        abortSignal: opts.abortSignal,
        fetchFn,
        keys,
      });
      return;
    }
    yield* streamGemini({
      model,
      messages: opts.messages,
      abortSignal: opts.abortSignal,
      fetchFn,
      keys,
    });
  } catch (err) {
    if (opts.abortSignal?.aborted) {
      yield { type: 'error', error: 'aborted', model };
      return;
    }
    const alt = fallbackModel(model);
    if (alt && keyAvailableFor(alt, keys)) {
      try {
        if (isGrokModel(alt)) {
          yield* streamXai({
            model: alt,
            messages: opts.messages,
            abortSignal: opts.abortSignal,
            fetchFn,
            keys,
          });
          return;
        }
        yield* streamGemini({
          model: alt,
          messages: opts.messages,
          abortSignal: opts.abortSignal,
          fetchFn,
          keys,
        });
        return;
      } catch (fallbackErr) {
        const message =
          fallbackErr instanceof Error ? fallbackErr.message : 'vendor_failed';
        yield { type: 'error', error: `fallback_failed: ${message}`, model: alt };
        return;
      }
    }
    const message = err instanceof Error ? err.message : 'vendor_failed';
    yield { type: 'error', error: message, model };
  }
}

async function* streamXai(opts: {
  model: ModelId;
  messages: ChatTurn[];
  abortSignal?: AbortSignal;
  fetchFn: FetchLike;
  keys: ReturnType<typeof resolveKeys>;
}): AsyncGenerator<StreamChunk> {
  const apiModel = vendorModelId(opts.model);
  const url = `${opts.keys.xaiBaseUrl.replace(/\/$/, '')}/chat/completions`;
  const res = await opts.fetchFn(url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${opts.keys.xaiApiKey}`,
      'Content-Type': 'application/json',
      Accept: 'text/event-stream',
    },
    body: JSON.stringify({
      model: apiModel,
      stream: true,
      messages: opts.messages.map((m) => ({
        role: m.role === 'system' ? 'system' : m.role,
        content: m.content,
      })),
    }),
    signal: opts.abortSignal,
  });

  if (!res.ok || !res.body) {
    const body = res.body ? await res.text() : '';
    throw new Error(`xai_http_${res.status}: ${body.slice(0, 300)}`);
  }

  yield { type: 'meta', model: opts.model, vendor: 'xai' };

  let inputTokens = 0;
  let outputTokens = 0;
  let assembled = '';

  for await (const line of readSseLines(res.body, opts.abortSignal)) {
    if (line === '[DONE]') break;
    let json: {
      choices?: Array<{ delta?: { content?: string } }>;
      usage?: { prompt_tokens?: number; completion_tokens?: number };
    };
    try {
      json = JSON.parse(line) as typeof json;
    } catch {
      continue;
    }
    const delta = json.choices?.[0]?.delta?.content;
    if (delta) {
      assembled += delta;
      yield { type: 'delta', text: delta, model: opts.model, vendor: 'xai' };
    }
    if (json.usage) {
      inputTokens = json.usage.prompt_tokens ?? inputTokens;
      outputTokens = json.usage.completion_tokens ?? outputTokens;
    }
  }

  if (!inputTokens) inputTokens = estimateTokens(
    opts.messages.map((m) => m.content).join(' '),
  );
  if (!outputTokens) outputTokens = estimateTokens(assembled);

  yield {
    type: 'done',
    model: opts.model,
    vendor: 'xai',
    inputTokens,
    outputTokens,
  };
}

async function* streamGemini(opts: {
  model: ModelId;
  messages: ChatTurn[];
  abortSignal?: AbortSignal;
  fetchFn: FetchLike;
  keys: ReturnType<typeof resolveKeys>;
}): AsyncGenerator<StreamChunk> {
  const apiModel = vendorModelId(opts.model);
  const url =
    `https://generativelanguage.googleapis.com/v1beta/models/` +
    `${apiModel}:streamGenerateContent?alt=sse&key=${encodeURIComponent(opts.keys.geminiApiKey)}`;

  const systemBits = opts.messages
    .filter((m) => m.role === 'system')
    .map((m) => m.content)
    .join('\n');
  const contents = opts.messages
    .filter((m) => m.role !== 'system')
    .map((m) => ({
      role: m.role === 'assistant' ? 'model' : 'user',
      parts: [{ text: m.content }],
    }));

  const body: Record<string, unknown> = { contents };
  if (systemBits) {
    body.systemInstruction = { parts: [{ text: systemBits }] };
  }

  const res = await opts.fetchFn(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Accept: 'text/event-stream',
    },
    body: JSON.stringify(body),
    signal: opts.abortSignal,
  });

  if (!res.ok || !res.body) {
    const text = res.body ? await res.text() : '';
    throw new Error(`gemini_http_${res.status}: ${text.slice(0, 300)}`);
  }

  yield { type: 'meta', model: opts.model, vendor: 'gemini' };

  let inputTokens = 0;
  let outputTokens = 0;
  let assembled = '';

  for await (const line of readSseLines(res.body, opts.abortSignal)) {
    let json: {
      candidates?: Array<{
        content?: { parts?: Array<{ text?: string }> };
      }>;
      usageMetadata?: {
        promptTokenCount?: number;
        candidatesTokenCount?: number;
      };
    };
    try {
      json = JSON.parse(line) as typeof json;
    } catch {
      continue;
    }
    const text = json.candidates?.[0]?.content?.parts
      ?.map((p) => p.text ?? '')
      .join('');
    if (text) {
      assembled += text;
      yield { type: 'delta', text, model: opts.model, vendor: 'gemini' };
    }
    if (json.usageMetadata) {
      inputTokens = json.usageMetadata.promptTokenCount ?? inputTokens;
      outputTokens =
        json.usageMetadata.candidatesTokenCount ?? outputTokens;
    }
  }

  if (!inputTokens) {
    inputTokens = estimateTokens(opts.messages.map((m) => m.content).join(' '));
  }
  if (!outputTokens) outputTokens = estimateTokens(assembled);

  yield {
    type: 'done',
    model: opts.model,
    vendor: 'gemini',
    inputTokens,
    outputTokens,
  };
}

async function* readSseLines(
  body: ReadableStream<Uint8Array>,
  abortSignal?: AbortSignal,
): AsyncGenerator<string> {
  const reader = body.getReader();
  const decoder = new TextDecoder();
  let buffer = '';
  try {
    while (true) {
      if (abortSignal?.aborted) break;
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const parts = buffer.split('\n');
      buffer = parts.pop() ?? '';
      for (const raw of parts) {
        const line = raw.trimEnd();
        if (!line.startsWith('data:')) continue;
        const payload = line.slice(5).trim();
        if (!payload) continue;
        yield payload;
      }
    }
    if (buffer.trim().startsWith('data:')) {
      yield buffer.trim().slice(5).trim();
    }
  } finally {
    try {
      reader.releaseLock();
    } catch {
      /* ignore */
    }
  }
}
