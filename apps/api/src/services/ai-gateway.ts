import { config } from '../config.js';
import type { PlanTier } from '../config.js';
import type { ModelId } from '../types/index.js';
import {
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
  vendor?: 'xai' | 'stub';
}

export type FetchLike = typeof fetch;

export interface GatewayDeps {
  fetchFn?: FetchLike;
  xaiApiKey?: string;
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
    xaiBaseUrl: deps.xaiBaseUrl ?? config.ai.xaiBaseUrl,
  };
}

async function* stubStream(
  model: ModelId,
  lastUser: string,
  abortSignal?: AbortSignal,
): AsyncGenerator<StreamChunk> {
  const stub =
    `[Orbita stub · ${model}] XAI_API_KEY not configured. ` +
    `Set XAI_API_KEY on the server for Grok. ` +
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

/**
 * Stream completion from xAI Grok only.
 * Missing key → clear stub stream (no crash).
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
  const model = resolveModel(opts.planTier, opts.model);
  const lastUser =
    [...opts.messages].reverse().find((m) => m.role === 'user')?.content ?? '';

  if (!keys.xaiApiKey || !isGrokModel(model)) {
    yield* stubStream(model, lastUser, opts.abortSignal);
    return;
  }

  try {
    yield* streamXai({
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

  if (!inputTokens) {
    inputTokens = estimateTokens(
      opts.messages.map((m) => m.content).join(' '),
    );
  }
  if (!outputTokens) outputTokens = estimateTokens(assembled);

  yield {
    type: 'done',
    model: opts.model,
    vendor: 'xai',
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
