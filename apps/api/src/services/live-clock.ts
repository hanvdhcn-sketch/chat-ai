/** Default local zone for Orbita (user base: Vietnam). */
export const ORBITA_LOCAL_TIMEZONE = 'Asia/Saigon';

export interface LiveClockSnapshot {
  /** UTC instant as ISO-8601 with milliseconds. */
  utcIso: string;
  /** Asia/Saigon wall clock with seconds, e.g. 2026-11-23 15:37:42. */
  localDateTime: string;
  /** Localized weekday name in English (stable for the model). */
  weekdayEn: string;
  /** Calendar date in Asia/Saigon, YYYY-MM-DD. */
  localDate: string;
  /** IANA timezone id. */
  timeZone: string;
  /** Fixed offset label for Saigon. */
  utcOffset: string;
}

function pad2(n: number): string {
  return String(n).padStart(2, '0');
}

/**
 * Authoritative "now" from the API host clock (Date.now()).
 * Prefer this over web_search time snippets for "what time is it".
 */
export function snapshotLiveClock(
  now: Date = new Date(),
  timeZone: string = ORBITA_LOCAL_TIMEZONE,
): LiveClockSnapshot {
  const utcIso = now.toISOString();

  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    weekday: 'long',
    hourCycle: 'h23',
  }).formatToParts(now);

  const get = (type: Intl.DateTimeFormatPartTypes): string =>
    parts.find((p) => p.type === type)?.value ?? '';

  const year = get('year');
  const month = get('month');
  const day = get('day');
  const hour = get('hour');
  const minute = get('minute');
  const second = get('second');
  const weekdayEn = get('weekday');

  const localDate = `${year}-${month}-${day}`;
  const localDateTime = `${localDate} ${pad2(Number(hour))}:${pad2(Number(minute))}:${pad2(Number(second))}`;

  return {
    utcIso,
    localDateTime,
    weekdayEn,
    localDate,
    timeZone,
    utcOffset: 'UTC+7',
  };
}

/**
 * Compact system-prompt block. Always inject so calendar / relative
 * questions ("tomorrow", "this evening") share the same ground truth.
 */
export function buildLiveClockSystemBlock(
  now: Date = new Date(),
  locale: 'en' | 'vi' = 'en',
): string {
  const c = snapshotLiveClock(now);
  if (locale === 'vi') {
    return [
      '## Thời gian hiện tại (đồng hồ máy chủ API — nguồn chuẩn)',
      `UTC: ${c.utcIso}`,
      `${c.timeZone} (${c.utcOffset}): ${c.localDateTime} (${c.weekdayEn})`,
      'Với câu hỏi "mấy giờ rồi / hiện tại / bây giờ": dùng khối này làm sự thật — không bịa giờ và không ưu tiên trang đồng hồ từ web_search (time.is, World Clock, v.v.) vì snippet có thể trễ hàng chục giây đến vài phút. Vẫn được dùng web search cho tin tức và sự kiện khác.',
    ].join('\n');
  }
  return [
    '## Current time (API host clock — ground truth)',
    `UTC: ${c.utcIso}`,
    `${c.timeZone} (${c.utcOffset}): ${c.localDateTime} (${c.weekdayEn})`,
    'For "what time is it now / hiện tại": use THIS block as ground truth. Do not invent a clock and do not prefer web_search clock pages (time.is, World Clock, etc.) over it — those snippets can lag by tens of seconds to minutes. Web search may still be used for other facts.',
  ].join('\n');
}
