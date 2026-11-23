import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  ORBITA_LOCAL_TIMEZONE,
  buildLiveClockSystemBlock,
  snapshotLiveClock,
} from './live-clock.js';

describe('live-clock', () => {
  it('snapshots UTC + Asia/Saigon wall clock with seconds', () => {
    // 2026-11-23T08:33:05.000Z → Asia/Saigon 15:33:05 (UTC+7)
    const fixed = new Date('2026-11-23T08:33:05.000Z');
    const snap = snapshotLiveClock(fixed);
    assert.equal(snap.utcIso, '2026-11-23T08:33:05.000Z');
    assert.equal(snap.timeZone, ORBITA_LOCAL_TIMEZONE);
    assert.equal(snap.utcOffset, 'UTC+7');
    assert.equal(snap.localDate, '2026-11-23');
    assert.equal(snap.localDateTime, '2026-11-23 15:33:05');
    assert.equal(snap.weekdayEn, 'Monday');
  });

  it('builds English system block instructing model to trust host clock', () => {
    const fixed = new Date('2026-11-23T08:33:05.000Z');
    const block = buildLiveClockSystemBlock(fixed, 'en');
    assert.match(block, /Current time \(API host clock/);
    assert.match(block, /2026-11-23T08:33:05\.000Z/);
    assert.match(block, /Asia\/Saigon/);
    assert.match(block, /15:33:05/);
    assert.match(block, /Monday/);
    assert.match(block, /ground truth/i);
    assert.match(block, /time\.is/i);
  });

  it('builds Vietnamese system block', () => {
    const fixed = new Date('2026-11-23T08:33:05.000Z');
    const block = buildLiveClockSystemBlock(fixed, 'vi');
    assert.match(block, /Thời gian hiện tại/);
    assert.match(block, /15:33:05/);
    assert.match(block, /nguồn chuẩn/);
  });
});
