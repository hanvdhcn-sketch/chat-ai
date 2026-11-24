import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { resolveModel, streamCompletion } from './ai-gateway.js';
import {
  coerceModelId,
  fallbackModel,
  vendorVisionModelId,
} from './model-catalog.js';

function sseResponse(lines: string[], status = 200): Response {
  const body = lines.map((l) => `data: ${l}\n\n`).join('');
  return new Response(body, {
    status,
    headers: { 'Content-Type': 'text/event-stream' },
  });
}

async function collect(
  gen: AsyncGenerator<{
    type: string;
    text?: string;
    model?: string;
    stub?: boolean;
    error?: string;
    vendor?: string;
    webSearch?: boolean;
    inputTokens?: number;
    outputTokens?: number;
  }>,
) {
  const out: Array<Record<string, unknown>> = [];
  for await (const chunk of gen) out.push(chunk as Record<string, unknown>);
  return out;
}

describe('resolveModel', () => {
  it('forces Grok Fast for Free regardless of request', () => {
    assert.equal(resolveModel('free', 'grok'), 'grok-fast');
    assert.equal(resolveModel('free', 'grok-fast'), 'grok-fast');
    assert.equal(resolveModel('free'), 'grok-fast');
  });

  it('defaults Pro to Grok and honors grok-fast', () => {
    assert.equal(resolveModel('pro'), 'grok');
    assert.equal(resolveModel('pro', 'grok-fast'), 'grok-fast');
    assert.equal(resolveModel('pro', 'grok'), 'grok');
  });

  it('has no cross-vendor fallback', () => {
    assert.equal(fallbackModel('grok'), null);
    assert.equal(fallbackModel('grok-fast'), null);
  });

  it('coerces legacy Gemini ids onto Grok', () => {
    assert.equal(coerceModelId('gemini-flash'), 'grok-fast');
    assert.equal(coerceModelId('gemini-pro'), 'grok-fast');
    assert.equal(coerceModelId('grok'), 'grok');
  });
});

describe('streamCompletion', () => {
  it('falls back to stub when no XAI key (no crash)', async () => {
    const chunks = await collect(
      streamCompletion(
        {
          planTier: 'free',
          messages: [{ role: 'user', content: 'hi' }],
        },
        { xaiApiKey: '' },
      ),
    );
    assert.ok(chunks.some((c) => c.type === 'delta'));
    assert.ok(chunks.some((c) => c.type === 'done' && c.stub === true));
    assert.equal(chunks.find((c) => c.type === 'done')?.model, 'grok-fast');
  });

  it('streams xAI Grok SSE when key + fetch mock present', async () => {
    const fetchFn: typeof fetch = async () =>
      sseResponse([
        JSON.stringify({ choices: [{ delta: { content: 'Hello' } }] }),
        JSON.stringify({ choices: [{ delta: { content: ' Grok' } }] }),
        JSON.stringify({
          choices: [{ delta: {} }],
          usage: { prompt_tokens: 3, completion_tokens: 2 },
        }),
        '[DONE]',
      ]);

    const chunks = await collect(
      streamCompletion(
        {
          planTier: 'pro',
          model: 'grok',
          messages: [{ role: 'user', content: 'hi' }],
        },
        { fetchFn, xaiApiKey: 'test-xai', webSearchMode: 'off' },
      ),
    );

    const text = chunks
      .filter((c) => c.type === 'delta')
      .map((c) => c.text)
      .join('');
    assert.equal(text, 'Hello Grok');
    const done = chunks.find((c) => c.type === 'done');
    assert.equal(done?.vendor, 'xai');
    assert.equal(done?.inputTokens, 3);
    assert.equal(done?.outputTokens, 2);
  });

  it('returns error when Grok HTTP fails (no Gemini fallback)', async () => {
    const fetchFn: typeof fetch = async () =>
      new Response('boom', { status: 500 });

    const chunks = await collect(
      streamCompletion(
        {
          planTier: 'pro',
          model: 'grok',
          messages: [{ role: 'user', content: 'hi' }],
        },
        { fetchFn, xaiApiKey: 'xai', webSearchMode: 'off' },
      ),
    );

    assert.ok(chunks.some((c) => c.type === 'error'));
    assert.match(String(chunks.find((c) => c.type === 'error')?.error), /xai_http/);
  });

  it('streams Responses API text deltas when webSearchMode=xai', async () => {
    const fetchFn: typeof fetch = async (input) => {
      assert.match(String(input), /\/responses$/);
      return sseResponse([
        JSON.stringify({
          type: 'response.output_text.delta',
          delta: 'It is ',
        }),
        JSON.stringify({
          type: 'response.output_text.delta',
          delta: '14:30 in Vietnam.',
        }),
        JSON.stringify({
          type: 'response.completed',
          response: {
            usage: { input_tokens: 40, output_tokens: 8 },
          },
        }),
        '[DONE]',
      ]);
    };

    const chunks = await collect(
      streamCompletion(
        {
          planTier: 'pro',
          model: 'grok',
          messages: [{ role: 'user', content: 'What time is it in Vietnam?' }],
        },
        { fetchFn, xaiApiKey: 'test-xai', webSearchMode: 'xai' },
      ),
    );

    const text = chunks
      .filter((c) => c.type === 'delta')
      .map((c) => c.text)
      .join('');
    assert.equal(text, 'It is 14:30 in Vietnam.');
    const meta = chunks.find((c) => c.type === 'meta');
    assert.equal(meta?.webSearch, true);
    const done = chunks.find((c) => c.type === 'done');
    assert.equal(done?.inputTokens, 40);
    assert.equal(done?.outputTokens, 8);
  });

  it('runs local web_search tool loop with mocked search', async () => {
    let chatCalls = 0;
    const fetchFn: typeof fetch = async (input, init) => {
      const url = String(input);
      assert.match(url, /\/chat\/completions$/);
      chatCalls += 1;
      const body = JSON.parse(String(init?.body ?? '{}')) as {
        tools?: unknown[];
        messages?: Array<{ role?: string }>;
      };

      if (chatCalls === 1) {
        assert.ok(body.tools?.length);
        return new Response(
          JSON.stringify({
            choices: [
              {
                finish_reason: 'tool_calls',
                message: {
                  role: 'assistant',
                  content: null,
                  tool_calls: [
                    {
                      id: 'call_1',
                      type: 'function',
                      function: {
                        name: 'web_search',
                        arguments: JSON.stringify({
                          query: 'current time Vietnam',
                        }),
                      },
                    },
                  ],
                },
              },
            ],
            usage: { prompt_tokens: 20, completion_tokens: 5 },
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        );
      }

      // Second round: model answers with tool results in history.
      assert.ok(body.messages?.some((m) => m.role === 'tool'));
      return new Response(
        JSON.stringify({
          choices: [
            {
              finish_reason: 'stop',
              message: {
                role: 'assistant',
                content: 'Bây giờ ở Việt Nam khoảng 14:30.',
              },
            },
          ],
          usage: { prompt_tokens: 80, completion_tokens: 12 },
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
    };

    const webSearchFn = async (query: string) => {
      assert.match(query, /Vietnam|Việt/i);
      return [
        {
          title: 'Time in Vietnam',
          url: 'https://example.com/vn-time',
          snippet: 'Current local time in Vietnam is 14:30 ICT.',
        },
      ];
    };

    const chunks = await collect(
      streamCompletion(
        {
          planTier: 'free',
          messages: [{ role: 'user', content: 'Bây giờ ở Việt Nam mấy giờ?' }],
        },
        {
          fetchFn,
          xaiApiKey: 'test-xai',
          webSearchMode: 'local',
          webSearchFn,
        },
      ),
    );

    const text = chunks
      .filter((c) => c.type === 'delta')
      .map((c) => c.text)
      .join('');
    assert.match(text, /14:30/);
    assert.equal(chatCalls, 2);
    assert.equal(chunks.find((c) => c.type === 'done')?.webSearch, true);
  });

  it('skips tools when webSearchMode=off', async () => {
    const fetchFn: typeof fetch = async (input, init) => {
      assert.match(String(input), /\/chat\/completions$/);
      const body = JSON.parse(String(init?.body ?? '{}')) as {
        tools?: unknown;
        stream?: boolean;
      };
      assert.equal(body.tools, undefined);
      assert.equal(body.stream, true);
      return sseResponse([
        JSON.stringify({ choices: [{ delta: { content: 'ok' } }] }),
        '[DONE]',
      ]);
    };

    const chunks = await collect(
      streamCompletion(
        {
          planTier: 'pro',
          model: 'grok',
          messages: [{ role: 'user', content: 'hi' }],
        },
        { fetchFn, xaiApiKey: 'test-xai', webSearchMode: 'off' },
      ),
    );
    assert.equal(
      chunks.filter((c) => c.type === 'delta').map((c) => c.text).join(''),
      'ok',
    );
    assert.equal(chunks.find((c) => c.type === 'meta')?.webSearch, false);
  });

  it('defaults vision model to grok-4.7 and honors XAI_GROK_VISION_MODEL', () => {
    const prev = process.env.XAI_GROK_VISION_MODEL;
    try {
      delete process.env.XAI_GROK_VISION_MODEL;
      assert.equal(vendorVisionModelId(), 'grok-4.7');
      assert.notEqual(vendorVisionModelId(), 'grok-2-vision-1212');
      process.env.XAI_GROK_VISION_MODEL = 'grok-4.3';
      assert.equal(vendorVisionModelId(), 'grok-4.3');
    } finally {
      if (prev === undefined) delete process.env.XAI_GROK_VISION_MODEL;
      else process.env.XAI_GROK_VISION_MODEL = prev;
    }
  });

  it('routes Free image chats to vision model (not deleted grok-2-vision-1212)', async () => {
    const prev = process.env.XAI_GROK_VISION_MODEL;
    delete process.env.XAI_GROK_VISION_MODEL;
    try {
      let seenModel: string | undefined;
      const fetchFn: typeof fetch = async (_input, init) => {
        const body = JSON.parse(String(init?.body ?? '{}')) as { model?: string };
        seenModel = body.model;
        return sseResponse([
          JSON.stringify({ choices: [{ delta: { content: 'red square' } }] }),
          '[DONE]',
        ]);
      };

      const chunks = await collect(
        streamCompletion(
          {
            planTier: 'free',
            messages: [
              {
                role: 'user',
                content: [
                  { type: 'text', text: 'What color?' },
                  {
                    type: 'image_url',
                    image_url: {
                      url: 'data:image/png;base64,aaa',
                      detail: 'auto',
                    },
                  },
                ],
              },
            ],
          },
          { fetchFn, xaiApiKey: 'test-xai', webSearchMode: 'off' },
        ),
      );

      assert.equal(seenModel, 'grok-4.7');
      assert.notEqual(seenModel, 'grok-2-vision-1212');
      assert.equal(chunks.find((c) => c.type === 'done')?.model, 'grok-fast');
    } finally {
      if (prev === undefined) delete process.env.XAI_GROK_VISION_MODEL;
      else process.env.XAI_GROK_VISION_MODEL = prev;
    }
  });
});
