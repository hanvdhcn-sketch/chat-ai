import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  formatSearchHitsForModel,
  parseDuckDuckGoHtml,
  parseDuckDuckGoInstant,
  webSearch,
} from './web-search.js';

describe('parseDuckDuckGoInstant', () => {
  it('extracts abstract and related topics', () => {
    const hits = parseDuckDuckGoInstant(
      {
        Heading: 'Vietnam',
        AbstractText: 'A country in Southeast Asia.',
        AbstractURL: 'https://example.com/vietnam',
        RelatedTopics: [
          {
            Text: 'Hanoi - capital city',
            FirstURL: 'https://example.com/hanoi',
          },
          {
            Topics: [
              {
                Text: 'Ho Chi Minh City - largest city',
                FirstURL: 'https://example.com/hcmc',
              },
            ],
          },
        ],
      },
      5,
    );
    assert.equal(hits.length, 3);
    assert.equal(hits[0]?.url, 'https://example.com/vietnam');
    assert.match(hits[1]?.title ?? '', /Hanoi/);
    assert.match(hits[2]?.snippet ?? '', /largest city/);
  });

  it('returns empty for bad input', () => {
    assert.deepEqual(parseDuckDuckGoInstant(null, 5), []);
    assert.deepEqual(parseDuckDuckGoInstant({}, 5), []);
  });
});

describe('parseDuckDuckGoHtml', () => {
  it('parses result__a blocks', () => {
    const html = `
      <div class="result">
        <a class="result__a" href="https://time.is/Vietnam">Current time in Vietnam</a>
        <a class="result__snippet">The current local time in Vietnam is...</a>
      </div>
      <div class="result">
        <a class="result__a" href="//duckduckgo.com/l/?uddg=${encodeURIComponent('https://www.timeanddate.com/worldclock/vietnam')}">World Clock</a>
        <a class="result__snippet">Vietnam time zones</a>
      </div>
    `;
    const hits = parseDuckDuckGoHtml(html, 5);
    assert.equal(hits.length, 2);
    assert.equal(hits[0]?.url, 'https://time.is/Vietnam');
    assert.equal(hits[1]?.url, 'https://www.timeanddate.com/worldclock/vietnam');
  });
});

describe('formatSearchHitsForModel', () => {
  it('formats empty and populated lists', () => {
    assert.match(formatSearchHitsForModel([]), /No web search/);
    const text = formatSearchHitsForModel([
      { title: 'A', url: 'https://a.example', snippet: 'alpha' },
    ]);
    assert.match(text, /1\. A/);
    assert.match(text, /https:\/\/a\.example/);
  });
});

describe('webSearch', () => {
  it('uses Brave when key provided (mocked)', async () => {
    const fetchFn: typeof fetch = async (input) => {
      const url = String(input);
      assert.match(url, /api\.search\.brave\.com/);
      return new Response(
        JSON.stringify({
          web: {
            results: [
              {
                title: 'Vietnam time',
                url: 'https://example.com/vn-time',
                description: 'Current time in Vietnam',
              },
            ],
          },
        }),
        { status: 200, headers: { 'Content-Type': 'application/json' } },
      );
    };

    const hits = await webSearch('current time Vietnam', {
      fetchFn,
      braveApiKey: 'test-brave-key',
      timeoutMs: 2000,
    });
    assert.equal(hits.length, 1);
    assert.equal(hits[0]?.title, 'Vietnam time');
  });

  it('falls back to DuckDuckGo Instant when Brave empty', async () => {
    const calls: string[] = [];
    const fetchFn: typeof fetch = async (input) => {
      const url = String(input);
      calls.push(url);
      if (url.includes('api.duckduckgo.com')) {
        return new Response(
          JSON.stringify({
            Heading: 'Clock',
            AbstractText: 'It is afternoon in Hanoi.',
            AbstractURL: 'https://example.com/clock',
            RelatedTopics: [],
          }),
          { status: 200, headers: { 'Content-Type': 'application/json' } },
        );
      }
      if (url.includes('html.duckduckgo.com')) {
        return new Response('<html></html>', { status: 200 });
      }
      return new Response('nope', { status: 500 });
    };

    const hits = await webSearch('giờ Việt Nam', {
      fetchFn,
      timeoutMs: 2000,
    });
    assert.equal(hits.length, 1);
    assert.match(hits[0]?.snippet ?? '', /Hanoi/);
    assert.ok(calls.some((c) => c.includes('api.duckduckgo.com')));
  });

  it('returns [] for blank query', async () => {
    const hits = await webSearch('   ', {
      fetchFn: async () => {
        throw new Error('should not fetch');
      },
    });
    assert.deepEqual(hits, []);
  });
});
