import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { resolveModel, streamCompletion } from './ai-gateway.js';
import { fallbackModel } from './model-catalog.js';

function sseResponse(lines: string[], status = 200): Response {
  const body = lines.map((l) => `data: ${l}\n\n`).join('');
  return new Response(body, {
    status,
    headers: { 'Content-Type': 'text/event-stream' },
  });
}

async function collect(
  gen: AsyncGenerator<{ type: string; text?: string; model?: string; stub?: boolean; error?: string; vendor?: string }>,
) {
  const out: Array<Record<string, unknown>> = [];
  for await (const chunk of gen) out.push(chunk as Record<string, unknown>);
  return out;
}

describe('resolveModel', () => {
  it('forces Gemini Flash for Free regardless of request', () => {
    assert.equal(resolveModel('free', 'grok'), 'gemini-flash');
    assert.equal(resolveModel('free', 'gemini-pro'), 'gemini-flash');
    assert.equal(resolveModel('free'), 'gemini-flash');
  });

  it('defaults Pro to Grok and honors Gemini / Grok picks', () => {
    assert.equal(resolveModel('pro'), 'grok');
    assert.equal(resolveModel('pro', 'gemini-pro'), 'gemini-pro');
    assert.equal(resolveModel('pro', 'grok-fast'), 'grok-fast');
  });

  it('maps cross-vendor fallback', () => {
    assert.equal(fallbackModel('gemini-flash'), 'grok-fast');
    assert.equal(fallbackModel('grok'), 'gemini-flash');
  });
});

describe('streamCompletion', () => {
  it('falls back to stub when no keys (no crash)', async () => {
    const chunks = await collect(
      streamCompletion(
        {
          planTier: 'free',
          messages: [{ role: 'user', content: 'hi' }],
        },
        { xaiApiKey: '', geminiApiKey: '' },
      ),
    );
    assert.ok(chunks.some((c) => c.type === 'delta'));
    assert.ok(chunks.some((c) => c.type === 'done' && c.stub === true));
    assert.equal(
      chunks.find((c) => c.type === 'done')?.model,
      'gemini-flash',
    );
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
        { fetchFn, xaiApiKey: 'test-xai', geminiApiKey: '' },
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

  it('streams Gemini SSE when key + fetch mock present', async () => {
    const fetchFn: typeof fetch = async (input) => {
      assert.match(String(input), /generativelanguage\.googleapis\.com/);
      return sseResponse([
        JSON.stringify({
          candidates: [{ content: { parts: [{ text: 'Xin' }] } }],
        }),
        JSON.stringify({
          candidates: [{ content: { parts: [{ text: ' chào' }] } }],
          usageMetadata: { promptTokenCount: 5, candidatesTokenCount: 4 },
        }),
      ]);
    };

    const chunks = await collect(
      streamCompletion(
        {
          planTier: 'free',
          messages: [{ role: 'user', content: 'hi' }],
        },
        { fetchFn, geminiApiKey: 'test-gemini', xaiApiKey: '' },
      ),
    );

    const text = chunks
      .filter((c) => c.type === 'delta')
      .map((c) => c.text)
      .join('');
    assert.equal(text, 'Xin chào');
    assert.equal(chunks.find((c) => c.type === 'done')?.vendor, 'gemini');
  });

  it('falls back to Gemini when Grok HTTP fails and Gemini key exists', async () => {
    let calls = 0;
    const fetchFn: typeof fetch = async (input) => {
      calls += 1;
      const url = String(input);
      if (url.includes('api.x.ai')) {
        return new Response('boom', { status: 500 });
      }
      return sseResponse([
        JSON.stringify({
          candidates: [{ content: { parts: [{ text: 'fallback-ok' }] } }],
        }),
      ]);
    };

    const chunks = await collect(
      streamCompletion(
        {
          planTier: 'pro',
          model: 'grok',
          messages: [{ role: 'user', content: 'hi' }],
        },
        { fetchFn, xaiApiKey: 'xai', geminiApiKey: 'gem' },
      ),
    );

    assert.ok(calls >= 2);
    const text = chunks
      .filter((c) => c.type === 'delta')
      .map((c) => c.text)
      .join('');
    assert.equal(text, 'fallback-ok');
  });
});
