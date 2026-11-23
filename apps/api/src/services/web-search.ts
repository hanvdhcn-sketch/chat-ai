/**
 * Local / fallback web search for Orbita tool-calling.
 * Default provider: DuckDuckGo Instant Answer + HTML (no paid key).
 * Optional: Brave Search when BRAVE_SEARCH_API_KEY is set.
 */

export interface WebSearchHit {
  title: string;
  url: string;
  snippet: string;
}

export type FetchLike = typeof fetch;

export interface WebSearchDeps {
  fetchFn?: FetchLike;
  /** Brave Search API key — optional; enables Brave when set. */
  braveApiKey?: string;
  /** Max results to return (1–8). */
  maxResults?: number;
  /** Per-request timeout ms. */
  timeoutMs?: number;
  abortSignal?: AbortSignal;
}

const DDG_INSTANT = 'https://api.duckduckgo.com/';
const DDG_HTML = 'https://html.duckduckgo.com/html/';
const BRAVE_URL = 'https://api.search.brave.com/res/v1/web/search';

function clampResults(n: number | undefined): number {
  if (n === undefined) return 5;
  return Math.min(8, Math.max(1, Math.floor(n)));
}

function withTimeout(
  parent: AbortSignal | undefined,
  timeoutMs: number,
): { signal: AbortSignal; clear: () => void } {
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), timeoutMs);
  const onAbort = () => ctrl.abort();
  parent?.addEventListener('abort', onAbort, { once: true });
  return {
    signal: ctrl.signal,
    clear: () => {
      clearTimeout(timer);
      parent?.removeEventListener('abort', onAbort);
    },
  };
}

function decodeHtmlEntities(s: string): string {
  return s
    .replace(/&amp;/g, '&')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&quot;/g, '"')
    .replace(/&#39;/g, "'")
    .replace(/&#x27;/g, "'")
    .replace(/&#(\d+);/g, (_, n) => String.fromCharCode(Number(n)));
}

function stripTags(s: string): string {
  return decodeHtmlEntities(s.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim());
}

/** Parse DuckDuckGo Instant Answer JSON into hits. */
export function parseDuckDuckGoInstant(json: unknown, max: number): WebSearchHit[] {
  if (!json || typeof json !== 'object') return [];
  const data = json as Record<string, unknown>;
  const hits: WebSearchHit[] = [];

  const heading = typeof data.Heading === 'string' ? data.Heading : '';
  const abstract = typeof data.AbstractText === 'string' ? data.AbstractText : '';
  const abstractUrl = typeof data.AbstractURL === 'string' ? data.AbstractURL : '';
  if (abstract && abstractUrl) {
    hits.push({
      title: heading || abstractUrl,
      url: abstractUrl,
      snippet: abstract.slice(0, 400),
    });
  }

  const related = Array.isArray(data.RelatedTopics) ? data.RelatedTopics : [];
  for (const item of related) {
    if (hits.length >= max) break;
    if (!item || typeof item !== 'object') continue;
    const row = item as Record<string, unknown>;
    if (Array.isArray(row.Topics)) {
      for (const nested of row.Topics) {
        if (hits.length >= max) break;
        if (!nested || typeof nested !== 'object') continue;
        const n = nested as Record<string, unknown>;
        const text = typeof n.Text === 'string' ? n.Text : '';
        const url = typeof n.FirstURL === 'string' ? n.FirstURL : '';
        if (text && url) {
          hits.push({
            title: text.split(' - ')[0]?.slice(0, 120) || url,
            url,
            snippet: text.slice(0, 400),
          });
        }
      }
      continue;
    }
    const text = typeof row.Text === 'string' ? row.Text : '';
    const url = typeof row.FirstURL === 'string' ? row.FirstURL : '';
    if (text && url) {
      hits.push({
        title: text.split(' - ')[0]?.slice(0, 120) || url,
        url,
        snippet: text.slice(0, 400),
      });
    }
  }

  const results = Array.isArray(data.Results) ? data.Results : [];
  for (const item of results) {
    if (hits.length >= max) break;
    if (!item || typeof item !== 'object') continue;
    const row = item as Record<string, unknown>;
    const text = typeof row.Text === 'string' ? row.Text : '';
    const url = typeof row.FirstURL === 'string' ? row.FirstURL : '';
    if (text && url) {
      hits.push({
        title: text.split(' - ')[0]?.slice(0, 120) || url,
        url,
        snippet: text.slice(0, 400),
      });
    }
  }

  return hits.slice(0, max);
}

/** Parse DuckDuckGo HTML SERP into hits (best-effort; layout may change). */
export function parseDuckDuckGoHtml(html: string, max: number): WebSearchHit[] {
  const hits: WebSearchHit[] = [];
  // Result blocks: <a class="result__a" href="...">title</a> + snippet
  const blockRe =
    /<a[^>]*class="[^"]*result__a[^"]*"[^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>[\s\S]*?(?:class="[^"]*result__snippet[^"]*"[^>]*>([\s\S]*?)<\/(?:a|td|div)>|(?=<a[^>]*class="[^"]*result__a))/gi;
  let m: RegExpExecArray | null;
  while ((m = blockRe.exec(html)) !== null && hits.length < max) {
    const rawUrl = decodeHtmlEntities(m[1] ?? '');
    const title = stripTags(m[2] ?? '');
    const snippet = stripTags(m[3] ?? '');
    let url = rawUrl;
    // DDG sometimes wraps redirects: //duckduckgo.com/l/?uddg=<encoded>
    try {
      const u = new URL(rawUrl.startsWith('//') ? `https:${rawUrl}` : rawUrl);
      const uddg = u.searchParams.get('uddg');
      if (uddg) url = decodeURIComponent(uddg);
    } catch {
      /* keep raw */
    }
    if (!url || !title) continue;
    hits.push({ title: title.slice(0, 160), url, snippet: snippet.slice(0, 400) });
  }
  return hits;
}

async function searchDuckDuckGoInstant(
  query: string,
  deps: Required<Pick<WebSearchDeps, 'fetchFn' | 'maxResults' | 'timeoutMs'>> &
    Pick<WebSearchDeps, 'abortSignal'>,
): Promise<WebSearchHit[]> {
  const { signal, clear } = withTimeout(deps.abortSignal, deps.timeoutMs);
  try {
    const url = new URL(DDG_INSTANT);
    url.searchParams.set('q', query);
    url.searchParams.set('format', 'json');
    url.searchParams.set('no_html', '1');
    url.searchParams.set('skip_disambig', '1');
    const res = await deps.fetchFn(url.toString(), {
      method: 'GET',
      headers: { Accept: 'application/json' },
      signal,
    });
    if (!res.ok) return [];
    const json: unknown = await res.json();
    return parseDuckDuckGoInstant(json, deps.maxResults);
  } catch {
    return [];
  } finally {
    clear();
  }
}

async function searchDuckDuckGoHtml(
  query: string,
  deps: Required<Pick<WebSearchDeps, 'fetchFn' | 'maxResults' | 'timeoutMs'>> &
    Pick<WebSearchDeps, 'abortSignal'>,
): Promise<WebSearchHit[]> {
  const { signal, clear } = withTimeout(deps.abortSignal, deps.timeoutMs);
  try {
    const body = new URLSearchParams({ q: query });
    const res = await deps.fetchFn(DDG_HTML, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        Accept: 'text/html',
        'User-Agent': 'OrbitaChat/0.1 (+https://github.com/hanvdhcn-sketch/chat-ai)',
      },
      body: body.toString(),
      signal,
    });
    if (!res.ok) return [];
    const html = await res.text();
    return parseDuckDuckGoHtml(html, deps.maxResults);
  } catch {
    return [];
  } finally {
    clear();
  }
}

async function searchBrave(
  query: string,
  deps: Required<
    Pick<WebSearchDeps, 'fetchFn' | 'maxResults' | 'timeoutMs' | 'braveApiKey'>
  > &
    Pick<WebSearchDeps, 'abortSignal'>,
): Promise<WebSearchHit[]> {
  if (!deps.braveApiKey) return [];
  const { signal, clear } = withTimeout(deps.abortSignal, deps.timeoutMs);
  try {
    const url = new URL(BRAVE_URL);
    url.searchParams.set('q', query);
    url.searchParams.set('count', String(deps.maxResults));
    const res = await deps.fetchFn(url.toString(), {
      method: 'GET',
      headers: {
        Accept: 'application/json',
        'X-Subscription-Token': deps.braveApiKey,
      },
      signal,
    });
    if (!res.ok) return [];
    const json = (await res.json()) as {
      web?: { results?: Array<{ title?: string; url?: string; description?: string }> };
    };
    const rows = json.web?.results ?? [];
    return rows
      .filter((r) => r.title && r.url)
      .slice(0, deps.maxResults)
      .map((r) => ({
        title: String(r.title).slice(0, 160),
        url: String(r.url),
        snippet: String(r.description ?? '').slice(0, 400),
      }));
  } catch {
    return [];
  } finally {
    clear();
  }
}

/**
 * Run web search. Prefers Brave when key present; else DuckDuckGo Instant,
 * then DuckDuckGo HTML. Never throws — returns [] on failure.
 */
export async function webSearch(
  query: string,
  deps: WebSearchDeps = {},
): Promise<WebSearchHit[]> {
  const q = query.trim().slice(0, 400);
  if (!q) return [];

  const fetchFn = deps.fetchFn ?? fetch;
  const maxResults = clampResults(deps.maxResults);
  const timeoutMs = deps.timeoutMs ?? 8_000;
  const common = {
    fetchFn,
    maxResults,
    timeoutMs,
    abortSignal: deps.abortSignal,
  };

  const braveKey = deps.braveApiKey ?? process.env.BRAVE_SEARCH_API_KEY ?? '';
  if (braveKey) {
    const braveHits = await searchBrave(q, { ...common, braveApiKey: braveKey });
    if (braveHits.length) return braveHits;
  }

  const instant = await searchDuckDuckGoInstant(q, common);
  if (instant.length) return instant;

  return searchDuckDuckGoHtml(q, common);
}

/** Format hits for the model tool result. */
export function formatSearchHitsForModel(hits: WebSearchHit[]): string {
  if (!hits.length) {
    return 'No web search results found.';
  }
  return hits
    .map(
      (h, i) =>
        `${i + 1}. ${h.title}\n   URL: ${h.url}\n   ${h.snippet || '(no snippet)'}`,
    )
    .join('\n\n');
}

/** OpenAI-compatible function tool definition for web_search. */
export const WEB_SEARCH_TOOL = {
  type: 'function' as const,
  function: {
    name: 'web_search',
    description:
      'Search the live web for current facts, news, times, prices, or anything beyond training data. Use when the user needs up-to-date information.',
    parameters: {
      type: 'object',
      properties: {
        query: {
          type: 'string',
          description: 'Search query in the user\'s language when possible.',
        },
      },
      required: ['query'],
      additionalProperties: false,
    },
  },
};
