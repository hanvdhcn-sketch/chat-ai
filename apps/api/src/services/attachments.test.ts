import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  buildPersistedUserContent,
  buildUserTurnContent,
  sanitizeAttachments,
} from './attachments.js';

describe('attachments', () => {
  it('sanitizes and builds text context', () => {
    const atts = sanitizeAttachments([
      {
        name: 'notes.txt',
        mimeType: 'text/plain',
        kind: 'text',
        text: 'hello world',
      },
    ]);
    assert.equal(atts.length, 1);
    const persisted = buildPersistedUserContent('Summarize', atts);
    assert.match(persisted, /Attached file: notes\.txt/);
    assert.match(persisted, /hello world/);
    const content = buildUserTurnContent('Summarize', atts);
    assert.equal(typeof content, 'string');
  });

  it('builds multimodal parts for images', () => {
    const atts = sanitizeAttachments([
      {
        name: 'shot.png',
        mimeType: 'image/png',
        kind: 'image',
        dataBase64: 'abc123',
      },
    ]);
    const content = buildUserTurnContent('What is this?', atts);
    assert.ok(Array.isArray(content));
    const parts = content as Array<{ type: string }>;
    assert.equal(parts[0]?.type, 'image_url');
    assert.equal(parts[1]?.type, 'text');
  });

  it('keeps unsupported attachments visible in persisted text', () => {
    const atts = sanitizeAttachments([
      {
        name: 'doc.pdf',
        mimeType: 'application/pdf',
        kind: 'unsupported',
        notice: 'PDF text extraction is not supported yet on Windows.',
      },
    ]);
    const persisted = buildPersistedUserContent('', atts);
    assert.match(persisted, /Unsupported attachment: doc\.pdf/);
  });

  it('caps Free plan to 3 images per message', () => {
    const raw = [1, 2, 3, 4].map((n) => ({
      name: `i${n}.png`,
      mimeType: 'image/png' as const,
      kind: 'image' as const,
      dataBase64: 'abc',
    }));
    const atts = sanitizeAttachments(raw, 'free');
    assert.equal(atts.filter((a) => a.kind === 'image').length, 3);
  });

  it('caps Pro plan to 8 images per message', () => {
    const raw = Array.from({ length: 10 }, (_, n) => ({
      name: `i${n}.png`,
      mimeType: 'image/png' as const,
      kind: 'image' as const,
      dataBase64: 'abc',
    }));
    const atts = sanitizeAttachments(raw, 'pro');
    assert.equal(atts.filter((a) => a.kind === 'image').length, 8);
  });

  it('caps Pro to Free image rates after monthly soft-cap', () => {
    const raw = Array.from({ length: 6 }, (_, n) => ({
      name: `i${n}.png`,
      mimeType: 'image/png' as const,
      kind: 'image' as const,
      dataBase64: 'abc',
    }));
    const atts = sanitizeAttachments(raw, 'pro', { monthImagesCount: 200 });
    assert.equal(atts.filter((a) => a.kind === 'image').length, 3);
  });
});
