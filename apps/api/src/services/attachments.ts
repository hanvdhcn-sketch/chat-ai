import type { PlanTier } from '../config.js';
import { config } from '../config.js';
import type { UsageSnapshot } from '../types/index.js';
import type { ChatContent, ChatContentPart, ChatTurn } from './ai-gateway.js';
import { effectiveImageLimits } from './quota-context.js';

export type AttachmentKind = 'image' | 'text' | 'unsupported';

export interface IncomingAttachment {
  name: string;
  mimeType: string;
  kind: AttachmentKind;
  text?: string;
  dataBase64?: string;
  notice?: string;
}

const MAX_TEXT = 100_000;

/** Approx base64 length for a given raw byte limit (+ padding slack). */
function maxBase64ForBytes(maxBytes: number): number {
  return Math.ceil((maxBytes * 4) / 3) + 8;
}

export function sanitizeAttachments(
  raw: IncomingAttachment[] | undefined,
  planTier: PlanTier = 'free',
  usage?: Pick<UsageSnapshot, 'monthImagesCount'>,
): IncomingAttachment[] {
  if (!raw?.length) return [];
  const limits = effectiveImageLimits(planTier, usage);
  const maxB64 = maxBase64ForBytes(limits.maxImageBytes);
  const maxTotal = Math.max(limits.maxImagesPerMessage, 5);
  const out: IncomingAttachment[] = [];
  let imageCount = 0;

  for (const a of raw.slice(0, maxTotal)) {
    if (!a?.name || !a.kind) continue;
    if (a.kind === 'unsupported') {
      out.push({
        name: a.name.slice(0, 256),
        mimeType: (a.mimeType || 'application/octet-stream').slice(0, 128),
        kind: 'unsupported',
        notice: a.notice?.slice(0, 500),
      });
      continue;
    }
    if (a.kind === 'text') {
      const text = (a.text ?? '').slice(0, MAX_TEXT);
      if (!text) continue;
      out.push({
        name: a.name.slice(0, 256),
        mimeType: (a.mimeType || 'text/plain').slice(0, 128),
        kind: 'text',
        text,
        notice: a.notice?.slice(0, 500),
      });
      continue;
    }
    if (a.kind === 'image') {
      if (imageCount >= limits.maxImagesPerMessage) continue;
      const dataBase64 = (a.dataBase64 ?? '').slice(0, maxB64);
      if (!dataBase64) continue;
      // Reject oversize after decode estimate (~3/4 of b64 length).
      const approxBytes = Math.floor((dataBase64.length * 3) / 4);
      if (approxBytes > limits.maxImageBytes) continue;
      const mime = normalizeImageMime(a.mimeType);
      out.push({
        name: a.name.slice(0, 256),
        mimeType: mime,
        kind: 'image',
        dataBase64,
        notice: a.notice?.slice(0, 500),
      });
      imageCount += 1;
    }
  }
  return out;
}

function normalizeImageMime(mime?: string): string {
  const m = (mime ?? '').toLowerCase();
  if (m === 'image/png' || m === 'image/jpeg' || m === 'image/jpg') {
    return m === 'image/jpg' ? 'image/jpeg' : m;
  }
  // Client should re-encode webp/gif → png; default to png.
  return 'image/png';
}

/** Persistable plain-text form of the user turn (history + UI). */
export function buildPersistedUserContent(
  content: string,
  attachments: IncomingAttachment[],
): string {
  const parts: string[] = [];
  const trimmed = content.trim();
  if (trimmed) parts.push(trimmed);

  for (const a of attachments) {
    if (a.kind === 'image') {
      parts.push(`[Attached image: ${a.name}]`);
      if (a.notice) parts.push(`(${a.notice})`);
    } else if (a.kind === 'text' && a.text) {
      parts.push(`--- Attached file: ${a.name} ---`);
      if (a.notice) parts.push(`(${a.notice})`);
      parts.push(a.text);
      parts.push(`--- End of ${a.name} ---`);
    } else if (a.kind === 'unsupported') {
      parts.push(
        `[Unsupported attachment: ${a.name}${a.notice ? ` — ${a.notice}` : ''}]`,
      );
    }
  }

  return parts.join('\n\n').trim();
}

/** Multimodal content for the current user turn sent to xAI. */
export function buildUserTurnContent(
  content: string,
  attachments: IncomingAttachment[],
): ChatContent {
  const images = attachments.filter((a) => a.kind === 'image' && a.dataBase64);
  const textBody = buildPersistedUserContent(content, attachments);

  if (!images.length) {
    return textBody || content || '(empty)';
  }

  const parts: ChatContentPart[] = [];
  for (const img of images) {
    parts.push({
      type: 'image_url',
      image_url: {
        url: `data:${img.mimeType};base64,${img.dataBase64}`,
        detail: 'auto',
      },
    });
  }
  parts.push({
    type: 'text',
    text:
      textBody ||
      'Please describe and answer questions about the attached image(s).',
  });
  return parts;
}

export function hasImageAttachments(attachments: IncomingAttachment[]): boolean {
  return attachments.some((a) => a.kind === 'image' && !!a.dataBase64);
}

export function countImageAttachments(attachments: IncomingAttachment[]): number {
  return attachments.filter((a) => a.kind === 'image' && !!a.dataBase64).length;
}

/** Map stored history strings into ChatTurn[]; last user may be multimodal. */
export function toGatewayMessages(
  history: Array<{ role: 'user' | 'assistant' | 'system'; content: string }>,
  currentUserContent: ChatContent,
  systemPrompt?: string,
): ChatTurn[] {
  const prior = history.slice(0, -1).map((m) => ({
    role: m.role,
    content: m.content,
  }));
  const turns: ChatTurn[] = [
    ...prior,
    { role: 'user', content: currentUserContent },
  ];
  if (systemPrompt?.trim()) {
    return [{ role: 'system', content: systemPrompt.trim() }, ...turns];
  }
  return turns;
}

/** Max attachments accepted in the Zod body (covers Pro image cap + text). */
export const maxAttachmentsInBody = Math.max(
  config.quotas.proImagesPerMessage,
  5,
);
