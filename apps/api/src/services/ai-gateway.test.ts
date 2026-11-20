import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { resolveModel, streamCompletion } from './ai-gateway.js';
import { coerceModelId, fallbackModel } from './model-catalog.js';

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
        { fetchFn, xaiApiKey: 'test-xai' },
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
        { fetchFn, xaiApiKey: 'xai' },
      ),
    );

    assert.ok(chunks.some((c) => c.type === 'error'));
    assert.match(String(chunks.find((c) => c.type === 'error')?.error), /xai_http/);
  });
});
