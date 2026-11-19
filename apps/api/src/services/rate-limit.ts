/**
 * In-memory sliding-window rate limit (Redis later).
 * Keyed by userId; returns whether the request is allowed.
 */
const hits = new Map<string, number[]>();

export function checkRateLimit(
  userId: string,
  limitPerMin: number,
  nowMs = Date.now(),
): { ok: boolean; retryAfterSec?: number } {
  const windowMs = 60_000;
  const cutoff = nowMs - windowMs;
  const prev = (hits.get(userId) ?? []).filter((t) => t > cutoff);
  if (prev.length >= limitPerMin) {
    const oldest = prev[0] ?? nowMs;
    const retryAfterSec = Math.max(1, Math.ceil((oldest + windowMs - nowMs) / 1000));
    hits.set(userId, prev);
    return { ok: false, retryAfterSec };
  }
  prev.push(nowMs);
  hits.set(userId, prev);
  return { ok: true };
}

/** Test helper — clear counters between cases. */
export function resetRateLimits(): void {
  hits.clear();
}
