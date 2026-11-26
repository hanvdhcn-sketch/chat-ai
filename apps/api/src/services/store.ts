import type { Conversation, Message, UsageSnapshot } from '../types/index.js';
import type { PlanTier } from '../config.js';
import { config } from '../config.js';
import { isProMonthlyImageSoftCapActive } from './quota-context.js';
import { resetSubscriptions } from './subscriptions.js';

/**
 * In-memory store for conversations, messages and usage counters (single API
 * instance). Pro entitlements are NOT here — they persist in Postgres via
 * subscriptions.ts.
 */
const conversations = new Map<string, Conversation>();
const messages = new Map<string, Message[]>();
const usageByUser = new Map<string, UsageSnapshot>();

function dayStartIso(): string {
  const d = new Date();
  d.setUTCHours(0, 0, 0, 0);
  return d.toISOString();
}

export function monthStartIso(from: Date = new Date()): string {
  return new Date(
    Date.UTC(from.getUTCFullYear(), from.getUTCMonth(), 1),
  ).toISOString();
}

function resolveMonthCounters(
  prev: UsageSnapshot | undefined,
  monthStart: string,
): { monthImagesCount: number; monthWindowStart: string } {
  if (!prev) {
    return { monthImagesCount: 0, monthWindowStart: monthStart };
  }
  const prevMonth = prev.monthWindowStart ?? monthStartIso(new Date(prev.windowStart));
  if (prevMonth === monthStart) {
    return {
      monthImagesCount: prev.monthImagesCount ?? 0,
      monthWindowStart: prevMonth,
    };
  }
  return { monthImagesCount: 0, monthWindowStart: monthStart };
}

function applyPlanLimits(snap: UsageSnapshot, planTier: PlanTier): void {
  snap.planTier = planTier;
  snap.messagesLimit =
    planTier === 'pro'
      ? config.quotas.proMessagesPerDay
      : config.quotas.freeMessagesPerDay;
  const softCap = isProMonthlyImageSoftCapActive(snap, planTier);
  snap.imagesLimit =
    planTier === 'pro' && !softCap
      ? config.quotas.proImagesPerDay
      : config.quotas.freeImagesPerDay;
  if (snap.imagesCount === undefined) snap.imagesCount = 0;
  if (snap.monthImagesCount === undefined) snap.monthImagesCount = 0;
  if (!snap.monthWindowStart) snap.monthWindowStart = monthStartIso();
  snap.tokenSoftCap =
    planTier === 'pro'
      ? config.quotas.proTokenSoftCap
      : config.quotas.freeTokenSoftCap;
}

export function listConversations(userId: string): Conversation[] {
  return [...conversations.values()]
    .filter((c) => c.userId === userId && !c.archivedAt)
    .sort((a, b) => b.updatedAt.localeCompare(a.updatedAt));
}

export function getConversation(
  userId: string,
  id: string,
): Conversation | undefined {
  const c = conversations.get(id);
  if (!c || c.userId !== userId) return undefined;
  return c;
}

export function saveConversation(c: Conversation): void {
  conversations.set(c.id, c);
}

export function listMessages(conversationId: string): Message[] {
  return messages.get(conversationId) ?? [];
}

export function appendMessage(msg: Message): void {
  const list = messages.get(msg.conversationId) ?? [];
  list.push(msg);
  messages.set(msg.conversationId, list);
}

export function updateMessage(
  conversationId: string,
  messageId: string,
  patch: Partial<Message>,
): Message | undefined {
  const list = messages.get(conversationId);
  if (!list) return undefined;
  const idx = list.findIndex((m) => m.id === messageId);
  if (idx < 0) return undefined;
  list[idx] = { ...list[idx], ...patch };
  return list[idx];
}

export function getOrCreateUsage(
  userId: string,
  planTier: PlanTier,
): UsageSnapshot {
  const windowStart = dayStartIso();
  const monthStart = monthStartIso();
  let snap = usageByUser.get(userId);
  if (!snap || snap.windowStart !== windowStart) {
    const month = resolveMonthCounters(snap, monthStart);
    snap = {
      userId,
      window: 'day',
      windowStart,
      messagesCount: 0,
      messagesLimit: 0,
      imagesCount: 0,
      imagesLimit: 0,
      monthImagesCount: month.monthImagesCount,
      monthWindowStart: month.monthWindowStart,
      inputTokens: 0,
      outputTokens: 0,
      tokenSoftCap: 0,
      planTier,
    };
    applyPlanLimits(snap, planTier);
    usageByUser.set(userId, snap);
  } else {
    const month = resolveMonthCounters(snap, monthStart);
    snap.monthImagesCount = month.monthImagesCount;
    snap.monthWindowStart = month.monthWindowStart;
    applyPlanLimits(snap, planTier);
  }
  return snap;
}

export function incrementUsage(
  userId: string,
  planTier: PlanTier,
  opts: {
    messages?: number;
    images?: number;
    inputTokens?: number;
    outputTokens?: number;
  },
): UsageSnapshot {
  const snap = getOrCreateUsage(userId, planTier);
  snap.messagesCount += opts.messages ?? 0;
  const images = opts.images ?? 0;
  snap.imagesCount = (snap.imagesCount ?? 0) + images;
  snap.monthImagesCount = (snap.monthImagesCount ?? 0) + images;
  snap.inputTokens += opts.inputTokens ?? 0;
  snap.outputTokens += opts.outputTokens ?? 0;
  applyPlanLimits(snap, planTier);
  usageByUser.set(userId, snap);
  return snap;
}

/** Test helper */
export function resetStore(): void {
  conversations.clear();
  messages.clear();
  usageByUser.clear();
  resetSubscriptions();
}

/** Test helper — force usage counters */
export function setUsageForTests(snap: UsageSnapshot): void {
  usageByUser.set(snap.userId, snap);
}
