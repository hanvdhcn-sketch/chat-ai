import { config } from '../config.js';
import type { PlanTier } from '../config.js';
import type { ModelId } from '../types/index.js';
import {
  isGrokModel,
  resolveModel,
  vendorModelId,
} from './model-catalog.js';
import {
  WEB_SEARCH_TOOL,
  formatSearchHitsForModel,
  webSearch,
  type WebSearchHit,
} from './web-search.js';

export type { ModelId };
export { resolveModel } from './model-catalog.js';

/** OpenAI-compatible content part for xAI vision. */
export type ChatContentPart =
  | { type: 'text'; text: string }
  | {
      type: 'image_url';
      image_url: { url: string; detail?: 'auto' | 'low' | 'high' };
    };

export type ChatContent = string | ChatContentPart[];

export interface ChatTurn {
  role: 'user' | 'assistant' | 'system';
  content: ChatContent;
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
  /** True when this turn may use / used web search tools. */
  webSearch?: boolean;
}

export type FetchLike = typeof fetch;

/** How Orbita obtains live web facts. */
export type WebSearchMode = 'xai' | 'local' | 'off';

export type WebSearchFn = (
  query: string,
  opts?: { abortSignal?: AbortSignal },
) => Promise<WebSearchHit[]>;

export interface GatewayDeps {
  fetchFn?: FetchLike;
  xaiApiKey?: string;
  xaiBaseUrl?: string;
  /** Override config web search mode. */
  webSearchMode?: WebSearchMode;
  /** Injected search for tests (local tool path). */
  webSearchFn?: WebSearchFn;
  /** Max local tool rounds per turn. */
  maxToolRounds?: number;
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

function contentToPlain(content: ChatContent): string {
  if (typeof content === 'string') return content;
  return content
    .map((p) => (p.type === 'text' ? p.text : '[image]'))
    .join(' ');
}

function estimateTokens(text: string): number {
  return Math.max(1, Math.ceil(text.length / 4));
}

function estimateTurnTokens(turn: ChatTurn): number {
  return estimateTokens(contentToPlain(turn.content));
}

function resolveKeys(deps: GatewayDeps) {
  return {
    xaiApiKey: deps.xaiApiKey ?? config.ai.xaiApiKey,
    xaiBaseUrl: deps.xaiBaseUrl ?? config.ai.xaiBaseUrl,
  };
}

function resolveWebSearchMode(deps: GatewayDeps): WebSearchMode {
  if (deps.webSearchMode) return deps.webSearchMode;
  return config.ai.webSearchMode;
}

function messagesHaveImages(messages: ChatTurn[]): boolean {
  return messages.some(
    (m) =>
      Array.isArray(m.content) &&
      m.content.some((p) => p.type === 'image_url'),
  );
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
  yield { type: 'meta', model, stub: true, vendor: 'stub', webSearch: false };
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
 * Web search (default): xAI Responses API built-in `web_search` when mode=xai;
 * local DuckDuckGo/Brave tool loop when mode=local; off skips tools.
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
  const lastUserRaw =
    [...opts.messages].reverse().find((m) => m.role === 'user')?.content ?? '';
  const lastUser = contentToPlain(lastUserRaw);
  const mode = resolveWebSearchMode(deps);
  const hasImages = messagesHaveImages(opts.messages);

  if (!keys.xaiApiKey || !isGrokModel(model)) {
    yield* stubStream(model, lastUser, opts.abortSignal);
    return;
  }

  try {
    // Vision stays on chat/completions (stable multimodal path).
    // Text + web: prefer xAI native Responses web_search, else local tools.
    if (!hasImages && mode === 'xai') {
      try {
        yield* streamXaiResponses({
          model,
          messages: opts.messages,
          abortSignal: opts.abortSignal,
          fetchFn,
          keys,
          enableWebSearch: true,
        });
        return;
      } catch (err) {
        if (opts.abortSignal?.aborted) {
          yield { type: 'error', error: 'aborted', model };
          return;
        }
        const message = err instanceof Error ? err.message : String(err);
        // Only fall back to local tools when Responses endpoint is unavailable.
        if (/xai_http_(404|405|410|501)/.test(message)) {
          yield* streamXaiWithLocalTools({
            model,
            messages: opts.messages,
            abortSignal: opts.abortSignal,
            fetchFn,
            keys,
            deps,
            enableTools: true,
          });
          return;
        }
        yield { type: 'error', error: message, model };
        return;
      }
    }

    if (!hasImages && mode === 'local') {
      yield* streamXaiWithLocalTools({
        model,
        messages: opts.messages,
        abortSignal: opts.abortSignal,
        fetchFn,
        keys,
        deps,
        enableTools: true,
      });
      return;
    }

    yield* streamXaiChatCompletions({
      model,
      messages: opts.messages,
      abortSignal: opts.abortSignal,
      fetchFn,
      keys,
      webSearch: false,
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

function vendorModelForMessages(model: ModelId, messages: ChatTurn[]): string {
  if (messagesHaveImages(messages)) {
    return process.env.XAI_GROK_VISION_MODEL ?? 'grok-2-vision-1212';
  }
  return vendorModelId(model);
}

function toOpenAiMessages(messages: ChatTurn[]) {
  return messages.map((m) => ({
    role: m.role === 'system' ? ('system' as const) : m.role,
    content: m.content,
  }));
}

/** Map chat turns to Responses API `input` items. */
function toResponsesInput(messages: ChatTurn[]) {
  return messages.map((m) => {
    const role =
      m.role === 'system' ? 'system' : m.role === 'assistant' ? 'assistant' : 'user';
    if (typeof m.content === 'string') {
      return { role, content: m.content };
    }
    const parts = m.content.map((p) => {
      if (p.type === 'text') {
        return { type: 'input_text' as const, text: p.text };
      }
      return {
        type: 'input_image' as const,
        image_url: p.image_url.url,
        detail: p.image_url.detail ?? 'auto',
      };
    });
    return { role, content: parts };
  });
}

/**
 * xAI Responses API with server-side built-in `web_search`.
 * Requires only XAI_API_KEY — search runs on xAI servers.
 */
async function* streamXaiResponses(opts: {
  model: ModelId;
  messages: ChatTurn[];
  abortSignal?: AbortSignal;
  fetchFn: FetchLike;
  keys: ReturnType<typeof resolveKeys>;
  enableWebSearch: boolean;
}): AsyncGenerator<StreamChunk> {
  const apiModel = vendorModelForMessages(opts.model, opts.messages);
  const url = `${opts.keys.xaiBaseUrl.replace(/\/$/, '')}/responses`;
  const timeoutMs = config.ai.webSearchTimeoutMs;
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  const onParentAbort = () => ctrl.abort();
  opts.abortSignal?.addEventListener('abort', onParentAbort, { once: true });

  let res: Response;
  try {
    res = await opts.fetchFn(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${opts.keys.xaiApiKey}`,
        'Content-Type': 'application/json',
        Accept: 'text/event-stream',
      },
      body: JSON.stringify({
        model: apiModel,
        stream: true,
        input: toResponsesInput(opts.messages),
        ...(opts.enableWebSearch
          ? { tools: [{ type: 'web_search' }] }
          : {}),
      }),
      signal: ctrl.signal,
    });
  } finally {
    clearTimeout(timer);
    opts.abortSignal?.removeEventListener('abort', onParentAbort);
  }

  if (!res.ok || !res.body) {
    const body = res.body ? await res.text() : '';
    throw new Error(`xai_http_${res.status}: responses ${body.slice(0, 300)}`);
  }

  yield {
    type: 'meta',
    model: opts.model,
    vendor: 'xai',
    webSearch: opts.enableWebSearch,
  };

  let inputTokens = 0;
  let outputTokens = 0;
  let assembled = '';

  for await (const line of readSseLines(res.body, opts.abortSignal)) {
    if (line === '[DONE]') break;
    let json: {
      type?: string;
      delta?: string;
      response?: {
        usage?: {
          input_tokens?: number;
          output_tokens?: number;
          prompt_tokens?: number;
          completion_tokens?: number;
        };
      };
      usage?: {
        input_tokens?: number;
        output_tokens?: number;
        prompt_tokens?: number;
        completion_tokens?: number;
      };
    };
    try {
      json = JSON.parse(line) as typeof json;
    } catch {
      continue;
    }

    const eventType = json.type ?? '';
    if (
      eventType === 'response.output_text.delta' ||
      eventType === 'response.text.delta'
    ) {
      const delta = typeof json.delta === 'string' ? json.delta : '';
      if (delta) {
        assembled += delta;
        yield { type: 'delta', text: delta, model: opts.model, vendor: 'xai' };
      }
      continue;
    }

    // Some gateways mirror chat.completion.chunk shape on responses stream.
    const choiceDelta = (
      json as {
        choices?: Array<{ delta?: { content?: string } }>;
      }
    ).choices?.[0]?.delta?.content;
    if (choiceDelta) {
      assembled += choiceDelta;
      yield {
        type: 'delta',
        text: choiceDelta,
        model: opts.model,
        vendor: 'xai',
      };
    }

    const usage =
      json.response?.usage ??
      json.usage ??
      (
        json as {
          response?: { usage?: Record<string, number> };
        }
      ).response?.usage;
    if (usage) {
      inputTokens =
        usage.input_tokens ?? usage.prompt_tokens ?? inputTokens;
      outputTokens =
        usage.output_tokens ?? usage.completion_tokens ?? outputTokens;
    }
  }

  if (!inputTokens) {
    inputTokens = opts.messages.reduce(
      (sum, m) => sum + estimateTurnTokens(m),
      0,
    );
  }
  if (!outputTokens) outputTokens = estimateTokens(assembled);

  yield {
    type: 'done',
    model: opts.model,
    vendor: 'xai',
    inputTokens,
    outputTokens,
    webSearch: opts.enableWebSearch,
  };
}

type ToolCallMsg = {
  role: 'assistant';
  content: string | null;
  tool_calls: Array<{
    id: string;
    type: 'function';
    function: { name: string; arguments: string };
  }>;
};

type ToolResultMsg = {
  role: 'tool';
  tool_call_id: string;
  content: string;
};

type LoopMessage =
  | ReturnType<typeof toOpenAiMessages>[number]
  | ToolCallMsg
  | ToolResultMsg;

/**
 * Chat Completions + client-side `web_search` function tool loop
 * (DuckDuckGo / Brave). Used when XAI_WEB_SEARCH_MODE=local or as
 * fallback if Responses API is unavailable.
 */
async function* streamXaiWithLocalTools(opts: {
  model: ModelId;
  messages: ChatTurn[];
  abortSignal?: AbortSignal;
  fetchFn: FetchLike;
  keys: ReturnType<typeof resolveKeys>;
  deps: GatewayDeps;
  enableTools: boolean;
}): AsyncGenerator<StreamChunk> {
  const apiModel = vendorModelForMessages(opts.model, opts.messages);
  const url = `${opts.keys.xaiBaseUrl.replace(/\/$/, '')}/chat/completions`;
  const maxRounds = opts.deps.maxToolRounds ?? config.ai.webSearchMaxToolRounds;
  const searchFn: WebSearchFn =
    opts.deps.webSearchFn ??
    ((query, o) =>
      webSearch(query, {
        fetchFn: opts.fetchFn,
        timeoutMs: Math.min(config.ai.webSearchTimeoutMs, 12_000),
        abortSignal: o?.abortSignal ?? opts.abortSignal,
        maxResults: 5,
      }));

  yield {
    type: 'meta',
    model: opts.model,
    vendor: 'xai',
    webSearch: opts.enableTools,
  };

  const loopMessages: LoopMessage[] = [...toOpenAiMessages(opts.messages)];
  let inputTokens = 0;
  let outputTokens = 0;
  let usedSearch = false;

  for (let round = 0; round < maxRounds; round++) {
    if (opts.abortSignal?.aborted) {
      yield { type: 'error', error: 'aborted', model: opts.model };
      return;
    }

    const res = await opts.fetchFn(url, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${opts.keys.xaiApiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: apiModel,
        stream: false,
        messages: loopMessages,
        ...(opts.enableTools ? { tools: [WEB_SEARCH_TOOL], tool_choice: 'auto' } : {}),
      }),
      signal: opts.abortSignal,
    });

    if (!res.ok) {
      const body = await res.text();
      throw new Error(`xai_http_${res.status}: ${body.slice(0, 300)}`);
    }

    const json = (await res.json()) as {
      choices?: Array<{
        finish_reason?: string;
        message?: {
          role?: string;
          content?: string | null;
          tool_calls?: ToolCallMsg['tool_calls'];
        };
      }>;
      usage?: { prompt_tokens?: number; completion_tokens?: number };
    };

    if (json.usage) {
      inputTokens += json.usage.prompt_tokens ?? 0;
      outputTokens += json.usage.completion_tokens ?? 0;
    }

    const choice = json.choices?.[0];
    const msg = choice?.message;
    const toolCalls = msg?.tool_calls?.filter(
      (t) => t.type === 'function' && t.function?.name === 'web_search',
    );

    if (
      toolCalls?.length &&
      (choice?.finish_reason === 'tool_calls' || toolCalls.length > 0)
    ) {
      usedSearch = true;
      loopMessages.push({
        role: 'assistant',
        content: msg?.content ?? null,
        tool_calls: toolCalls,
      });

      for (const call of toolCalls) {
        let query = '';
        try {
          const args = JSON.parse(call.function.arguments || '{}') as {
            query?: string;
          };
          query = String(args.query ?? '').trim();
        } catch {
          query = '';
        }
        const hits = query
          ? await searchFn(query, { abortSignal: opts.abortSignal })
          : [];
        loopMessages.push({
          role: 'tool',
          tool_call_id: call.id,
          content: formatSearchHitsForModel(hits),
        });
      }
      continue;
    }

    // Final answer — stream via a second request for UX, or emit content now.
    const finalText = (msg?.content ?? '').toString();
    if (finalText) {
      // Emit in small chunks so the client SSE path stays consistent.
      const words = finalText.split(/(\s+)/);
      for (const word of words) {
        if (opts.abortSignal?.aborted) {
          yield { type: 'error', error: 'aborted', model: opts.model };
          return;
        }
        if (!word) continue;
        yield { type: 'delta', text: word, model: opts.model, vendor: 'xai' };
      }
      yield {
        type: 'done',
        model: opts.model,
        vendor: 'xai',
        inputTokens: inputTokens || estimateTurnTokens(opts.messages[0]!),
        outputTokens: outputTokens || estimateTokens(finalText),
        webSearch: usedSearch,
      };
      return;
    }

    // Empty content without tools — stream a follow-up without tools.
    break;
  }

  // Stream final completion without tools (after tool rounds exhausted or empty).
  yield* streamXaiChatCompletions({
    model: opts.model,
    messages: opts.messages,
    abortSignal: opts.abortSignal,
    fetchFn: opts.fetchFn,
    keys: opts.keys,
    webSearch: usedSearch,
    overrideMessages: loopMessages,
  });
}

async function* streamXaiChatCompletions(opts: {
  model: ModelId;
  messages: ChatTurn[];
  abortSignal?: AbortSignal;
  fetchFn: FetchLike;
  keys: ReturnType<typeof resolveKeys>;
  webSearch: boolean;
  overrideMessages?: LoopMessage[];
}): AsyncGenerator<StreamChunk> {
  const apiModel = vendorModelForMessages(opts.model, opts.messages);
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
      messages: opts.overrideMessages ?? toOpenAiMessages(opts.messages),
    }),
    signal: opts.abortSignal,
  });

  if (!res.ok || !res.body) {
    const body = res.body ? await res.text() : '';
    throw new Error(`xai_http_${res.status}: ${body.slice(0, 300)}`);
  }

  // meta already emitted by local-tools path; emit when called directly.
  if (!opts.overrideMessages) {
    yield {
      type: 'meta',
      model: opts.model,
      vendor: 'xai',
      webSearch: opts.webSearch,
    };
  }

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
    inputTokens = opts.messages.reduce(
      (sum, m) => sum + estimateTurnTokens(m),
      0,
    );
  }
  if (!outputTokens) outputTokens = estimateTokens(assembled);

  yield {
    type: 'done',
    model: opts.model,
    vendor: 'xai',
    inputTokens,
    outputTokens,
    webSearch: opts.webSearch,
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
